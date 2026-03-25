import 'dart:typed_data';

import '../../api/models/bookmark_model.dart';
import '../../api/models/feed_model.dart';
import '../../api/models/image_model.dart';
import '../../api/models/user_model.dart';

class HomepageData {
  final List<FeedCategory> feeds;
  final List<SameImage> images;
  final bool fromCache;

  const HomepageData({
    required this.feeds,
    required this.images,
    this.fromCache = false,
  });
}

class SearchData {
  final List<SameImage> images;
  final int? eligibleCount;
  final double? secondsTaken;
  final String? modelId;

  const SearchData({
    required this.images,
    this.eligibleCount,
    this.secondsTaken,
    this.modelId,
  });
}

class UploadData {
  final String imageId;
  final String sha1;
  final int? width;
  final int? height;

  const UploadData({
    required this.imageId,
    required this.sha1,
    this.width,
    this.height,
  });
}

class AuthData {
  final String userId;
  final String token;

  const AuthData({required this.userId, required this.token});
}

abstract class SameEnergyRepository {
  Future<HomepageData> fetchHomepage({required UserState user, String? index});

  Future<List<SameImage>> fetchFeed(String feedId);

  Future<SearchData> search({
    String? imageId,
    String? text,
    int n = 100,
    bool nsfw = true,
  });

  Future<SameImage?> getImageInfo(String imageId);

  Future<UploadData> uploadImage({
    required Uint8List bytes,
    required String contentType,
    void Function(int sent, int total)? onSendProgress,
  });

  Future<List<Bookmark>> readBookmarks(UserState user);

  Future<void> appendBookmark(
    UserState user, {
    required String imageId,
    String? collection,
    bool removed = false,
  });

  Future<Map<String, dynamic>> readSettings(UserState user);

  Future<AuthData?> createUser({
    required String userId,
    required String passwordHash,
  });

  Future<AuthData?> login({
    required String userId,
    required String passwordHash,
  });

  Future<AuthData?> legacyEmailLogin({
    required String email,
    required String anonymousUserId,
  });
}
