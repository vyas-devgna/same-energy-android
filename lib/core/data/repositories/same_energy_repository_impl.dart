import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/endpoints.dart';
import '../../api/models/bookmark_model.dart';
import '../../api/models/feed_model.dart';
import '../../api/models/image_model.dart';
import '../../api/models/user_model.dart';
import '../../domain/repositories/same_energy_repository.dart';
import '../../storage/json_cache_storage.dart';
import '../../storage/preferences_storage.dart';
import '../remote/same_energy_remote_data_source.dart';
import '../remote/stream_response_parser.dart';

final sameEnergyRepositoryProvider = Provider<SameEnergyRepository>((ref) {
  final apiClient = ApiClient();
  return SameEnergyRepositoryImpl(
    remote: SameEnergyRemoteDataSource(apiClient.dio),
    cache: JsonCacheStorage(PreferencesStorage.prefs),
  );
});

class SameEnergyRepositoryImpl implements SameEnergyRepository {
  SameEnergyRepositoryImpl({
    required SameEnergyRemoteDataSource remote,
    required JsonCacheStorage cache,
  }) : _remote = remote,
       _cache = cache;

  final SameEnergyRemoteDataSource _remote;
  final JsonCacheStorage _cache;

  static const _defaultFeedNames = [
    'Variety',
    'Paintings',
    'Forest',
    'People',
    'Pink-ish',
    'Streetwear',
    'Majestic',
    'Bizarre',
    'Patterns',
    '3D Renders',
    'Diagrams',
    'Lonely',
  ];

  @override
  Future<HomepageData> fetchHomepage({
    required UserState user,
    String? index,
  }) async {
    final cacheKey = 'homepage::${index ?? 'default'}::${user.userId}';
    try {
      final response = await _remote.postStream(
        Endpoints.homepage,
        data: jsonEncode({
          'user_id': user.userId.isNotEmpty
              ? user.userId
              : PreferencesStorage.getAnonymousUserId(),
          'token': user.token,
        }),
        queryParameters: index != null && index.isNotEmpty
            ? {'index': index}
            : null,
      );
      final payload = response.successPayload ?? const <String, dynamic>{};
      final images = _extractImages(payload);
      final feeds = _extractFeeds(payload, images);
      if (images.isNotEmpty) {
        await _cache.write(cacheKey, {
          'feeds': feeds
              .map((e) => {'name': e.name, 'ids': e.imageIds})
              .toList(),
          'images': images.map((e) => e.toJson()).toList(),
        });
        return HomepageData(feeds: feeds, images: images);
      }
    } catch (_) {}

    final cached = _cache.read(cacheKey, maxAge: const Duration(hours: 12));
    if (cached != null) {
      final feeds = _cachedFeeds(cached['feeds']);
      final images = _cachedImages(cached['images']);
      if (images.isNotEmpty) {
        return HomepageData(feeds: feeds, images: images, fromCache: true);
      }
    }

    final fallbackImages = await _fallbackHomepageImages();
    return HomepageData(
      feeds: _defaultFeedNames.map((name) => FeedCategory(name: name)).toList(),
      images: fallbackImages,
      fromCache: true,
    );
  }

  @override
  Future<List<SameImage>> fetchFeed(String feedId) async {
    final cacheKey = 'feed::$feedId';
    try {
      final response = await _remote.postStream(
        Endpoints.feed,
        queryParameters: {'id': feedId},
      );
      final payload = response.successPayload ?? const <String, dynamic>{};
      final images = _extractImages(payload);
      if (images.isNotEmpty) {
        await _cache.write(cacheKey, {
          'images': images.map((e) => e.toJson()).toList(),
        });
        return images;
      }
    } catch (_) {}

    final cached = _cache.read(cacheKey, maxAge: const Duration(hours: 24));
    if (cached != null) {
      final images = _cachedImages(cached['images']);
      if (images.isNotEmpty) return images;
    }
    return const [];
  }

  @override
  Future<SearchData> search({
    String? imageId,
    String? text,
    int n = 100,
    bool nsfw = true,
  }) async {
    final hasImage = imageId != null && imageId.isNotEmpty;
    final hasText = text != null && text.trim().isNotEmpty;
    if (!hasImage && !hasText) return const SearchData(images: []);

    final query = <String, dynamic>{'n': n.toString()};
    if (hasImage) query['i'] = imageId;
    if (hasText) query['text'] = text.trim();
    // Always send nsfw parameter for all search types
    query['nsfw'] = nsfw ? '1' : '0';

    final cacheKey =
        'search::${query['i'] ?? ''}::${query['text'] ?? ''}::${query['n']}::${query['nsfw'] ?? ''}';

    try {
      final response = await _remote.getStream(
        Endpoints.search,
        queryParameters: query,
      );
      final payload = response.successPayload ?? const <String, dynamic>{};
      final images = _extractImages(payload);
      if (images.isNotEmpty) {
        await _cache.write(cacheKey, {
          'images': images.map((e) => e.toJson()).toList(),
          'n_eligible': payload['n_eligible'],
          'seconds_taken': payload['seconds_taken'],
          'model_id': payload['model_id'],
        });
      }
      return SearchData(
        images: images,
        eligibleCount: (payload['n_eligible'] as num?)?.toInt(),
        secondsTaken: (payload['seconds_taken'] as num?)?.toDouble(),
        modelId: payload['model_id']?.toString(),
      );
    } catch (_) {
      final cached = _cache.read(cacheKey, maxAge: const Duration(hours: 6));
      if (cached != null) {
        return SearchData(
          images: _cachedImages(cached['images']),
          eligibleCount: (cached['n_eligible'] as num?)?.toInt(),
          secondsTaken: (cached['seconds_taken'] as num?)?.toDouble(),
          modelId: cached['model_id']?.toString(),
        );
      }
      throw Exception('Search request failed. Please check your connection and try again.');
    }
  }

  @override
  Future<SameImage?> getImageInfo(String imageId) async {
    try {
      final response = await _remote.getStream(
        Endpoints.imageInfo,
        queryParameters: {'i': imageId},
      );
      final payload = response.successPayload ?? const <String, dynamic>{};
      final images = _extractImages(payload);
      if (images.isNotEmpty) return images.first;
    } catch (_) {}
    return null;
  }

  @override
  Future<UploadData> uploadImage({
    required Uint8List bytes,
    required String contentType,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final hash = sha1.convert(bytes).toString();
    final response = await _remote.putStream(
      Endpoints.upload,
      queryParameters: {'length': bytes.length.toString()},
      headers: {'content-type': contentType},
      data: bytes,
      onSendProgress: onSendProgress,
    );
    final payload = response.successPayload ?? const <String, dynamic>{};
    final imageId = payload['id']?.toString() ?? payload['sha1']?.toString();
    if (imageId == null || imageId.isEmpty) {
      throw Exception('Upload completed without a valid image id.');
    }
    return UploadData(
      imageId: imageId,
      sha1: payload['sha1']?.toString() ?? hash,
      width: (payload['width'] as num?)?.toInt(),
      height: (payload['height'] as num?)?.toInt(),
    );
  }

  @override
  Future<List<Bookmark>> readBookmarks(UserState user) async {
    if (!user.isAuthenticated) return const [];
    try {
      final raw = await _remote.postRaw(
        Endpoints.userData,
        data: jsonEncode({
          'path': 'bookmarks.jsonl',
          'kind': 'read',
          'user_id': user.userId,
          'token': user.token,
        }),
      );
      final parsed = StreamResponseParser.parse(raw);
      final payload = parsed.successPayload;

      if (payload != null) {
        final images = payload['bookmarks'];
        if (images is List) {
          return images
              .whereType<Map<String, dynamic>>()
              .map(Bookmark.fromJson)
              .where((b) => b.id.isNotEmpty)
              .toList();
        }
      }

      return _parseBookmarkJsonl(raw);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> appendBookmark(
    UserState user, {
    required String imageId,
    String? collection,
    bool removed = false,
  }) async {
    if (!user.isAuthenticated) return;
    await _remote.postStream(
      Endpoints.userData,
      data: jsonEncode({
        'kind': 'append',
        'path': 'bookmarks.jsonl',
        'data': {
          'kind': 'bookmark',
          'id': imageId,
          if (collection != null && collection.isNotEmpty)
            'collection': collection,
          if (removed) 'removed': true,
        },
        'user_id': user.userId,
        'token': user.token,
      }),
    );
  }

  @override
  Future<Map<String, dynamic>> readSettings(UserState user) async {
    try {
      final raw = await _remote.postRaw(
        Endpoints.userData,
        data: jsonEncode({
          'kind': 'read',
          'path': 'settings.json',
          'default': {},
          'user_id': user.userId,
          'token': user.token,
        }),
      );
      final parsed = StreamResponseParser.parse(raw);
      if (parsed.successPayload != null) return parsed.successPayload!;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<AuthData?> createUser({
    required String userId,
    required String passwordHash,
  }) async {
    return _authRequest(
      Endpoints.createUser,
      userId: userId,
      passwordHash: passwordHash,
    );
  }

  @override
  Future<AuthData?> login({
    required String userId,
    required String passwordHash,
  }) async {
    return _authRequest(
      Endpoints.login,
      userId: userId,
      passwordHash: passwordHash,
    );
  }

  @override
  Future<AuthData?> legacyEmailLogin({
    required String email,
    required String anonymousUserId,
  }) async {
    try {
      final response = await _remote.postStream(
        Endpoints.userData,
        data: jsonEncode({
          'kind': 'login',
          'email': email,
          'user_id': anonymousUserId,
          'token': '',
        }),
      );
      final payload = response.successPayload;
      if (payload == null) return null;
      return _extractAuthData(payload, fallbackUserId: email);
    } catch (_) {
      return null;
    }
  }

  Future<AuthData?> _authRequest(
    String endpoint, {
    required String userId,
    required String passwordHash,
  }) async {
    try {
      final response = await _remote.postStream(
        endpoint,
        data: jsonEncode({'user_id': userId, 'password_hash': passwordHash}),
      );
      final payload = response.successPayload;
      if (payload == null) return null;
      return _extractAuthData(payload, fallbackUserId: userId);
    } catch (_) {
      return null;
    }
  }

  AuthData? _extractAuthData(
    Map<String, dynamic> payload, {
    required String fallbackUserId,
  }) {
    final token = _findString(payload, const [
      'token',
      'auth_token',
      'session_token',
    ]);
    if (token == null || token.isEmpty) return null;

    final userId =
        _findString(payload, const ['user_id', 'email', 'username']) ??
        fallbackUserId;
    return AuthData(userId: userId, token: token);
  }

  String? _findString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    for (final value in data.values) {
      if (value is Map<String, dynamic>) {
        final nested = _findString(value, keys);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  List<Bookmark> _parseBookmarkJsonl(String raw) {
    final bookmarks = <Bookmark>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final bookmark = Bookmark.fromJson(decoded);
          if (bookmark.id.isNotEmpty) bookmarks.add(bookmark);
        }
      } catch (_) {}
    }
    return bookmarks;
  }

  List<FeedCategory> _extractFeeds(
    Map<String, dynamic> payload,
    List<SameImage> images,
  ) {
    final feedsRaw = payload['feeds'];
    if (feedsRaw is List) {
      final parsed = feedsRaw
          .map((item) {
            if (item is String) return FeedCategory(name: item);
            if (item is Map<String, dynamic>) {
              return FeedCategory.fromJson(item);
            }
            return null;
          })
          .whereType<FeedCategory>()
          .where((feed) => feed.name.isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) return parsed;
    }

    return _defaultFeedNames.map((name) => FeedCategory(name: name)).toList();
  }

  List<SameImage> _extractImages(Map<String, dynamic> payload) {
    final imagesRaw = payload['images'] ?? payload['results'];
    if (imagesRaw is List) {
      return imagesRaw
          .whereType<Map<String, dynamic>>()
          .map(SameImage.fromJson)
          .where((image) => image.id.isNotEmpty)
          .toList();
    }

    if (payload['id'] != null) {
      final image = SameImage.fromJson(payload);
      if (image.id.isNotEmpty) return [image];
    }

    return const [];
  }

  Future<List<SameImage>> _fallbackHomepageImages() async {
    final futures = _defaultFeedNames.take(4).map((name) => fetchFeed(name));
    final results = await Future.wait(futures);
    final candidates = results.expand((e) => e).toList();
    
    final unique = <String, SameImage>{};
    for (final image in candidates) {
      unique[image.id] = image;
      if (unique.length >= 120) break;
    }
    return unique.values.toList();
  }

  List<FeedCategory> _cachedFeeds(dynamic value) {
    if (value is! List) {
      return _defaultFeedNames.map((name) => FeedCategory(name: name)).toList();
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(FeedCategory.fromJson)
        .where((feed) => feed.name.isNotEmpty)
        .toList();
  }

  List<SameImage> _cachedImages(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(SameImage.fromJson)
        .where((image) => image.id.isNotEmpty)
        .toList();
  }
}
