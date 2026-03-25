import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/endpoints.dart';
import '../../core/api/models/bookmark_model.dart';
import '../../core/api/models/image_model.dart';
import '../../core/api/models/user_model.dart';
import '../../core/auth/auth_state.dart';
import '../../core/data/repositories/same_energy_repository_impl.dart';
import '../../core/storage/preferences_storage.dart';

const uncategorizedCollectionId = 'uncategorized';
const uncategorizedCollectionName = 'Uncategorized';

class SavedImageItem {
  final String id;
  final String imageUrl;
  final String thumbnailUrl;
  final String? sourceUrl;
  final DateTime savedAt;
  final Set<String> collectionIds;

  const SavedImageItem({
    required this.id,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.savedAt,
    required this.collectionIds,
    this.sourceUrl,
  });

  SavedImageItem copyWith({
    String? id,
    String? imageUrl,
    String? thumbnailUrl,
    String? sourceUrl,
    DateTime? savedAt,
    Set<String>? collectionIds,
  }) {
    return SavedImageItem(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      savedAt: savedAt ?? this.savedAt,
      collectionIds: collectionIds ?? this.collectionIds,
    );
  }

  SameImage toSameImage() {
    return SameImage(
      id: id,
      thumbnailUrl: thumbnailUrl.isNotEmpty ? thumbnailUrl : imageUrl,
      sourceUrl: sourceUrl,
      aspectRatio: null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'image_url': imageUrl,
    'thumbnail_url': thumbnailUrl,
    'source_url': sourceUrl,
    'saved_at': savedAt.toIso8601String(),
    'collection_ids': collectionIds.toList(),
  };

  factory SavedImageItem.fromJson(Map<String, dynamic> json) {
    return SavedImageItem(
      id: json['id']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      sourceUrl: json['source_url']?.toString(),
      savedAt:
          DateTime.tryParse(json['saved_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      collectionIds: (json['collection_ids'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toSet(),
    );
  }
}

class SavedCollection {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<String> imageIds;
  final String? coverImageId;
  final bool isPrivate;

  const SavedCollection({
    required this.id,
    required this.name,
    required this.createdAt,
    this.imageIds = const [],
    this.coverImageId,
    this.isPrivate = false,
  });

  SavedCollection copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<String>? imageIds,
    String? coverImageId,
    bool clearCover = false,
    bool? isPrivate,
  }) {
    return SavedCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      imageIds: imageIds ?? this.imageIds,
      coverImageId: clearCover ? null : (coverImageId ?? this.coverImageId),
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toIso8601String(),
    'image_ids': imageIds,
    if (coverImageId != null) 'cover_image_id': coverImageId,
    if (isPrivate) 'is_private': true,
  };

  factory SavedCollection.fromJson(Map<String, dynamic> json) {
    return SavedCollection(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      imageIds: (json['image_ids'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      coverImageId: json['cover_image_id']?.toString(),
      isPrivate: json['is_private'] == true,
    );
  }
}

class SavedState {
  final int version;
  final Map<String, SavedCollection> collections;
  final Map<String, SavedImageItem> images;
  final bool isLoading;
  final String? errorMessage;

  const SavedState({
    required this.version,
    required this.collections,
    required this.images,
    this.isLoading = false,
    this.errorMessage,
  });

  factory SavedState.initial() {
    final uncategorized = SavedCollection(
      id: uncategorizedCollectionId,
      name: uncategorizedCollectionName,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    return SavedState(
      version: 2,
      collections: {uncategorized.id: uncategorized},
      images: const {},
      isLoading: false,
      errorMessage: null,
    );
  }

  SavedState copyWith({
    int? version,
    Map<String, SavedCollection>? collections,
    Map<String, SavedImageItem>? images,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SavedState(
      version: version ?? this.version,
      collections: collections ?? this.collections,
      images: images ?? this.images,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  List<SavedCollection> get orderedCollections {
    final values = collections.values.toList();
    values.sort((a, b) {
      if (a.id == uncategorizedCollectionId) return 1;
      if (b.id == uncategorizedCollectionId) return -1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return values;
  }

  List<SavedImageItem> get orderedImages {
    final values = images.values.toList();
    values.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return values;
  }

  /// Images visible in "All Saved" — excludes images that belong
  /// exclusively to private collections.
  List<SavedImageItem> get publicOrderedImages {
    final privateIds = collections.values
        .where((c) => c.isPrivate)
        .map((c) => c.id)
        .toSet();
    if (privateIds.isEmpty) return orderedImages;
    return orderedImages.where((image) {
      return image.collectionIds.any((id) => !privateIds.contains(id));
    }).toList();
  }

  List<SavedImageItem> imagesForCollection(String collectionId) {
    final collection = collections[collectionId];
    if (collection == null) return const [];
    final orderedIds = <String>[];
    final seenIds = <String>{};
    for (final id in collection.imageIds) {
      if (!seenIds.add(id)) continue;
      if (images.containsKey(id)) {
        orderedIds.add(id);
      }
    }
    final items = orderedIds
        .map((id) => images[id])
        .whereType<SavedImageItem>()
        .toList();
    items.sort((a, b) {
      final firstIndex = collection.imageIds.indexOf(a.id);
      final secondIndex = collection.imageIds.indexOf(b.id);
      return firstIndex.compareTo(secondIndex);
    });
    return items;
  }

  Set<String> collectionIdsForImage(String imageId) {
    return images[imageId]?.collectionIds ?? const <String>{};
  }

  bool isSaved(String imageId) => images.containsKey(imageId);

  Map<String, dynamic> toJson() => {
    'version': version,
    'collections': collections.values.map((e) => e.toJson()).toList(),
    'images': images.values.map((e) => e.toJson()).toList(),
  };

  factory SavedState.fromJson(Map<String, dynamic> json) {
    final collections = <String, SavedCollection>{};
    final images = <String, SavedImageItem>{};

    final collectionsRaw = json['collections'];
    if (collectionsRaw is List) {
      for (final raw in collectionsRaw.whereType<Map<String, dynamic>>()) {
        final item = SavedCollection.fromJson(raw);
        if (item.id.isNotEmpty) {
          collections[item.id] = item;
        }
      }
    }

    final imagesRaw = json['images'];
    if (imagesRaw is List) {
      for (final raw in imagesRaw.whereType<Map<String, dynamic>>()) {
        final item = SavedImageItem.fromJson(raw);
        if (item.id.isNotEmpty) {
          images[item.id] = item;
        }
      }
    }

    if (!collections.containsKey(uncategorizedCollectionId)) {
      collections[uncategorizedCollectionId] = SavedCollection(
        id: uncategorizedCollectionId,
        name: uncategorizedCollectionName,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }

    return SavedState(
      version: (json['version'] as num?)?.toInt() ?? 1,
      collections: collections,
      images: images,
    );
  }
}

final savedItemsProvider =
    StateNotifierProvider<SavedItemsNotifier, SavedState>((ref) {
      final notifier = SavedItemsNotifier(ref);
      ref.listen<UserState>(authStateProvider, (previous, next) {
        notifier.handleAuthChanged(previous, next);
      });
      return notifier;
    });

class SavedItemsNotifier extends StateNotifier<SavedState> {
  SavedItemsNotifier(this._ref) : super(SavedState.initial()) {
    _load();
  }

  final Ref _ref;

  static const _storageKey = 'saved_state_v2';
  static const _legacyStorageKey = 'saved_state_v1';
  static final _uuid = Uuid();

  final Set<String> _unlockedPrivateCollectionIds = <String>{};
  bool _syncInProgress = false;
  DateTime? _lastSyncedAt;

  bool get isSyncing => _syncInProgress;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  Future<void> _load() async {
    _unlockedPrivateCollectionIds.clear();
    _setStatus(isLoading: true, clearError: true);
    try {
      final raw =
          PreferencesStorage.prefs.getString(_storageKey) ??
          PreferencesStorage.prefs.getString(_legacyStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          state = SavedState.fromJson(decoded).copyWith(version: 2);
        }
      }
      _normalizeState();
      await _persist();
      await _syncFromRemote(
        mergeLocalFirst: _ref.read(authStateProvider).isAuthenticated,
        showLoading: false,
      );
      _setStatus(isLoading: false, clearError: true);
    } catch (error) {
      _setStatus(
        isLoading: false,
        errorMessage: 'Failed to load collections. Pull to retry.',
      );
    }
  }

  Future<void> handleAuthChanged(UserState? previous, UserState next) async {
    if (next.isAuthenticated) {
      await _syncFromRemote(mergeLocalFirst: previous?.isAuthenticated != true);
      return;
    }
    if (previous?.isAuthenticated == true && !next.isAuthenticated) {
      await _resetForSignOut();
      return;
    }
    lockAllCollectionSessions();
  }

  Future<void> _resetForSignOut() async {
    _unlockedPrivateCollectionIds.clear();
    state = SavedState.initial();
    await _persist();
  }

  Future<void> refreshFromServer() async {
    await _syncFromRemote(mergeLocalFirst: true, showLoading: true);
  }

  Future<void> _persist() async {
    _normalizeState();
    await PreferencesStorage.prefs.setString(
      _storageKey,
      jsonEncode(state.copyWith(version: 2).toJson()),
    );
  }

  void _setStatus({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    state = state.copyWith(
      isLoading: isLoading ?? state.isLoading,
      errorMessage: errorMessage ?? state.errorMessage,
      clearError: clearError,
    );
  }

  void _normalizeState() {
    final validCollections = Set<String>.from(state.collections.keys);
    final images = <String, SavedImageItem>{};

    for (final entry in state.images.entries) {
      final normalizedIds = entry.value.collectionIds
          .where(validCollections.contains)
          .toSet();
      if (normalizedIds.isEmpty) continue;
      images[entry.key] = entry.value.copyWith(collectionIds: normalizedIds);
    }

    final collections = <String, SavedCollection>{};
    for (final collection in state.collections.values) {
      final seen = <String>{};
      final normalizedImageIds = <String>[];
      for (final imageId in collection.imageIds) {
        if (!seen.add(imageId)) continue;
        if (!images.containsKey(imageId)) continue;
        normalizedImageIds.add(imageId);
      }

      final shouldClearCover =
          collection.coverImageId != null &&
          !images.containsKey(collection.coverImageId);
      final cleaned = collection.copyWith(
        imageIds: normalizedImageIds,
        clearCover: shouldClearCover,
      );

      collections[collection.id] = cleaned;
    }

    if (!collections.containsKey(uncategorizedCollectionId)) {
      collections[uncategorizedCollectionId] = SavedCollection(
        id: uncategorizedCollectionId,
        name: uncategorizedCollectionName,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }

    state = state.copyWith(collections: collections, images: images);
  }

  Future<String> createCollection(String name, {bool isPrivate = false}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw StateError('Collection name cannot be empty.');
    }

    final existingId = _findCollectionIdByName(trimmed);
    if (existingId != null) {
      throw StateError('A collection named "$trimmed" already exists.');
    }

    final id = _uuid.v4();
    final collection = SavedCollection(
      id: id,
      name: trimmed,
      createdAt: DateTime.now(),
      imageIds: const [],
      isPrivate: isPrivate,
    );
    final updated = Map<String, SavedCollection>.from(state.collections)
      ..[id] = collection;
    state = state.copyWith(collections: updated);
    await _persist();
    return id;
  }

  Future<void> renameCollection(String collectionId, String newName) async {
    final collection = state.collections[collectionId];
    if (collection == null || collection.id == uncategorizedCollectionId)
      return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw StateError('Collection name cannot be empty.');
    }

    final duplicateId = _findCollectionIdByName(trimmed);
    if (duplicateId != null && duplicateId != collectionId) {
      throw StateError('A collection named "$trimmed" already exists.');
    }

    final previousName = collection.name;
    final updated = Map<String, SavedCollection>.from(state.collections)
      ..[collectionId] = collection.copyWith(name: trimmed);
    state = state.copyWith(collections: updated);
    await _persist();
    await _syncCollectionRename(
      collectionId: collectionId,
      previousName: previousName,
      nextName: trimmed,
    );
  }

  Future<void> deleteCollection(String collectionId) async {
    if (collectionId == uncategorizedCollectionId) return;
    final collection = state.collections[collectionId];
    if (collection == null) return;

    final removedEvents = <String>[];
    final collections = Map<String, SavedCollection>.from(state.collections)
      ..remove(collectionId);
    final images = Map<String, SavedImageItem>.from(state.images);

    for (final imageId in collection.imageIds) {
      final image = images[imageId];
      if (image == null) continue;
      removedEvents.add(imageId);
      final nextCollectionIds = Set<String>.from(image.collectionIds)
        ..remove(collectionId);
      if (nextCollectionIds.isEmpty) {
        images.remove(imageId);
        for (final key in collections.keys.toList()) {
          final existing = collections[key];
          if (existing == null) continue;
          collections[key] = existing.copyWith(
            imageIds: existing.imageIds.where((id) => id != imageId).toList(),
            clearCover: existing.coverImageId == imageId,
          );
        }
      } else {
        images[imageId] = image.copyWith(collectionIds: nextCollectionIds);
      }
    }

    state = state.copyWith(collections: collections, images: images);
    _unlockedPrivateCollectionIds.remove(collectionId);
    await _persist();

    final user = _ref.read(authStateProvider);
    if (!user.isAuthenticated) return;
    final repository = _ref.read(sameEnergyRepositoryProvider);
    for (final imageId in removedEvents) {
      await repository.appendBookmark(
        user,
        imageId: imageId,
        collection: collection.name,
        removed: true,
      );
    }
  }

  Future<void> setCollectionPrivacy(String collectionId, bool isPrivate) async {
    final collection = state.collections[collectionId];
    if (collection == null || collection.id == uncategorizedCollectionId)
      return;
    final collections = Map<String, SavedCollection>.from(state.collections)
      ..[collectionId] = collection.copyWith(isPrivate: isPrivate);
    state = state.copyWith(collections: collections);
    if (!isPrivate) {
      _unlockedPrivateCollectionIds.add(collectionId);
    } else {
      _unlockedPrivateCollectionIds.remove(collectionId);
    }
    await _persist();
  }

  Future<void> setCollectionCover(String collectionId, String? imageId) async {
    final collection = state.collections[collectionId];
    if (collection == null) return;
    final collections = Map<String, SavedCollection>.from(state.collections)
      ..[collectionId] = collection.copyWith(
        coverImageId: imageId,
        clearCover: imageId == null,
      );
    state = state.copyWith(collections: collections);
    await _persist();
  }

  Future<void> saveImageToCollections(
    SameImage image,
    Set<String> selectedCollectionIds, {
    String? newCollectionName,
    bool newCollectionPrivate = false,
  }) async {
    final initialState = state;
    final collections = Map<String, SavedCollection>.from(state.collections);
    final images = Map<String, SavedImageItem>.from(state.images);
    final nextCollectionIds = selectedCollectionIds
        .where((id) => collections.containsKey(id))
        .toSet();
    final newCollection = newCollectionName?.trim() ?? '';
    if (newCollection.isNotEmpty) {
      final existingId = _findCollectionIdByName(newCollection);
      final collectionId =
          existingId ??
          await createCollection(newCollection, isPrivate: newCollectionPrivate);
      if (existingId != null) {
        final existingCollection = state.collections[existingId];
        if (existingCollection != null &&
            existingCollection.isPrivate != newCollectionPrivate) {
          await setCollectionPrivacy(existingId, newCollectionPrivate);
        }
      }
      nextCollectionIds.add(collectionId);
      collections
        ..clear()
        ..addAll(state.collections);
    }

    final existing = images[image.id];
    final previousCollectionIds = Set<String>.from(
      existing?.collectionIds ?? {},
    );
    if (nextCollectionIds.isEmpty) {
      await removeImage(image.id);
      return;
    }

    final now = DateTime.now();
    final imageUrl = image.displayThumbnailUrl.isNotEmpty
        ? image.displayThumbnailUrl
        : '${Endpoints.apiBase}${Endpoints.thumbnailById(image.id)}';
    final thumbnail = image.displayThumbnailUrl.isNotEmpty
        ? image.displayThumbnailUrl
        : imageUrl;
    final sourceUrl = image.sourceUrl ?? image.postUrl;
    final item =
        (existing ??
                SavedImageItem(
                  id: image.id,
                  imageUrl: imageUrl,
                  thumbnailUrl: thumbnail,
                  sourceUrl: sourceUrl,
                  savedAt: now,
                  collectionIds: nextCollectionIds,
                ))
            .copyWith(
              imageUrl: imageUrl,
              thumbnailUrl: thumbnail,
              sourceUrl: sourceUrl,
              savedAt: now,
              collectionIds: nextCollectionIds,
            );
    images[image.id] = item;

    for (final collectionId in collections.keys.toList()) {
      final collection = collections[collectionId];
      if (collection == null) continue;
      final ids = List<String>.from(collection.imageIds)
        ..removeWhere((id) => id == image.id);
      if (nextCollectionIds.contains(collectionId)) {
        ids.insert(0, image.id);
      }
      final shouldClearCover =
          collection.coverImageId != null &&
          collection.coverImageId == image.id &&
          !nextCollectionIds.contains(collectionId);
      collections[collectionId] = collection.copyWith(
        imageIds: ids,
        clearCover: shouldClearCover,
      );
    }

    state = state.copyWith(collections: collections, images: images);
    await _persist();
    try {
      await _syncBookmarkDelta(
        imageId: image.id,
        previousCollectionIds: previousCollectionIds,
        nextCollectionIds: nextCollectionIds,
      );
    } catch (_) {
      state = initialState;
      await _persist();
      rethrow;
    }
  }

  Future<void> toggleQuickSave(SameImage image) async {
    if (state.images.containsKey(image.id)) {
      await removeImage(image.id);
      return;
    }
    await saveImageToCollections(image, {uncategorizedCollectionId});
  }

  Future<void> removeImage(String imageId) async {
    final images = Map<String, SavedImageItem>.from(state.images);
    final previousCollectionIds = Set<String>.from(
      images[imageId]?.collectionIds ?? const <String>{},
    );
    if (!images.containsKey(imageId)) return;
    images.remove(imageId);

    final collections = Map<String, SavedCollection>.from(state.collections);
    for (final entry in collections.entries.toList()) {
      final filtered = entry.value.imageIds
          .where((id) => id != imageId)
          .toList();
      collections[entry.key] = entry.value.copyWith(
        imageIds: filtered,
        clearCover: entry.value.coverImageId == imageId,
      );
    }

    state = state.copyWith(collections: collections, images: images);
    await _persist();
    await _syncBookmarkDelta(
      imageId: imageId,
      previousCollectionIds: previousCollectionIds,
      nextCollectionIds: const <String>{},
    );
  }

  Future<void> removeImageFromCollection(
    String imageId,
    String collectionId,
  ) async {
    final image = state.images[imageId];
    final collection = state.collections[collectionId];
    if (image == null || collection == null) return;

    final nextCollectionIds = Set<String>.from(image.collectionIds)
      ..remove(collectionId);
    await saveImageToCollections(image.toSameImage(), nextCollectionIds);
  }

  Future<void> moveImageBetweenCollections({
    required String imageId,
    required String fromCollectionId,
    required String toCollectionId,
  }) async {
    final image = state.images[imageId];
    if (image == null) return;
    final nextCollectionIds = Set<String>.from(image.collectionIds)
      ..remove(fromCollectionId)
      ..add(toCollectionId);
    await saveImageToCollections(image.toSameImage(), nextCollectionIds);
  }

  Future<void> moveImagesToCollection({
    required Set<String> imageIds,
    required String toCollectionId,
    String? fromCollectionId,
  }) async {
    for (final imageId in imageIds) {
      final image = state.images[imageId];
      if (image == null) continue;
      final nextCollectionIds = Set<String>.from(image.collectionIds);
      if (fromCollectionId != null) {
        nextCollectionIds.remove(fromCollectionId);
      }
      nextCollectionIds.add(toCollectionId);
      await saveImageToCollections(image.toSameImage(), nextCollectionIds);
    }
  }

  Future<void> removeImagesFromCollection(
    Set<String> imageIds,
    String collectionId,
  ) async {
    for (final imageId in imageIds) {
      await removeImageFromCollection(imageId, collectionId);
    }
  }

  Future<void> moveImageWithinCollection({
    required String collectionId,
    required String imageId,
    required int targetIndex,
  }) async {
    final collection = state.collections[collectionId];
    if (collection == null) return;
    final ids = List<String>.from(collection.imageIds);
    final currentIndex = ids.indexOf(imageId);
    if (currentIndex < 0) return;

    ids.removeAt(currentIndex);
    final boundedIndex = targetIndex.clamp(0, ids.length);
    ids.insert(boundedIndex, imageId);

    final collections = Map<String, SavedCollection>.from(state.collections)
      ..[collectionId] = collection.copyWith(imageIds: ids);
    state = state.copyWith(collections: collections);
    await _persist();
  }

  Set<String> collectionIdsForImage(String imageId) {
    return state.collectionIdsForImage(imageId);
  }

  bool isSaved(String imageId) {
    return state.isSaved(imageId);
  }

  bool isCollectionUnlocked(String collectionId) {
    final collection = state.collections[collectionId];
    if (collection == null || !collection.isPrivate) return true;
    return _unlockedPrivateCollectionIds.contains(collectionId);
  }

  void unlockCollectionSession(String collectionId) {
    if (_unlockedPrivateCollectionIds.contains(collectionId)) return;
    _unlockedPrivateCollectionIds.add(collectionId);
    state = state.copyWith();
  }

  void lockCollectionSession(String collectionId) {
    if (!_unlockedPrivateCollectionIds.remove(collectionId)) return;
    state = state.copyWith();
  }

  void lockAllCollectionSessions() {
    if (_unlockedPrivateCollectionIds.isEmpty) return;
    _unlockedPrivateCollectionIds.clear();
    state = state.copyWith();
  }

  String? _findCollectionIdByName(String name) {
    for (final collection in state.collections.values) {
      if (collection.name.toLowerCase() == name.toLowerCase()) {
        return collection.id;
      }
    }
    return null;
  }

  Future<void> _syncBookmarkDelta({
    required String imageId,
    required Set<String> previousCollectionIds,
    required Set<String> nextCollectionIds,
  }) async {
    final user = _ref.read(authStateProvider);
    if (!user.isAuthenticated) return;

    final repository = _ref.read(sameEnergyRepositoryProvider);
    final additions = nextCollectionIds.difference(previousCollectionIds);
    final removals = previousCollectionIds.difference(nextCollectionIds);

    for (final collectionId in additions) {
      await repository.appendBookmark(
        user,
        imageId: imageId,
        collection: _collectionNameForId(collectionId),
      );
    }

    for (final collectionId in removals) {
      await repository.appendBookmark(
        user,
        imageId: imageId,
        collection: _collectionNameForId(collectionId),
        removed: true,
      );
    }

    _lastSyncedAt = DateTime.now();
  }

  Future<void> _syncCollectionRename({
    required String collectionId,
    required String previousName,
    required String nextName,
  }) async {
    final user = _ref.read(authStateProvider);
    if (!user.isAuthenticated) return;

    final repository = _ref.read(sameEnergyRepositoryProvider);
    final collection = state.collections[collectionId];
    if (collection == null) return;

    for (final imageId in collection.imageIds) {
      await repository.appendBookmark(
        user,
        imageId: imageId,
        collection: nextName,
      );
      await repository.appendBookmark(
        user,
        imageId: imageId,
        collection: previousName,
        removed: true,
      );
    }
    _lastSyncedAt = DateTime.now();
  }

  Future<void> _syncFromRemote({
    required bool mergeLocalFirst,
    bool showLoading = true,
  }) async {
    final user = _ref.read(authStateProvider);
    if (!user.isAuthenticated || _syncInProgress) return;

    if (showLoading) {
      _setStatus(isLoading: true);
    }
    _syncInProgress = true;
    try {
      final repository = _ref.read(sameEnergyRepositoryProvider);
      var events = await repository.readBookmarks(user);
      var remote = _buildRemoteBookmarkState(events);

      if (mergeLocalFirst) {
        await _pushMissingLocalBookmarks(user, remote);
        events = await repository.readBookmarks(user);
        remote = _buildRemoteBookmarkState(events);
      }

      await _applyRemoteBookmarkState(remote);
      _lastSyncedAt = DateTime.now();
      if (showLoading) {
        _setStatus(isLoading: false, clearError: true);
      }
    } catch (error) {
      if (showLoading) {
        _setStatus(
          isLoading: false,
          errorMessage: 'Could not sync with server. Please check your connection.',
        );
      } else {
        _setStatus(
          isLoading: false,
          clearError: false,
        );
      }
    } finally {
      _syncInProgress = false;
      if (showLoading && state.errorMessage == null) {
        _setStatus(isLoading: false);
      }
    }
  }

  _RemoteBookmarkState _buildRemoteBookmarkState(List<Bookmark> events) {
    final collectionImages = <String, List<String>>{};

    for (final event in events) {
      final collectionName = _normalizedCollectionName(event.collection);
      if (event.removed) {
        if (collectionName != null) {
          collectionImages[collectionName]?.removeWhere((id) => id == event.id);
        } else {
          for (final images in collectionImages.values) {
            images.removeWhere((id) => id == event.id);
          }
        }
        continue;
      }

      final effectiveCollection = collectionName ?? uncategorizedCollectionName;
      final ids = collectionImages.putIfAbsent(
        effectiveCollection,
        () => <String>[],
      );
      ids.removeWhere((id) => id == event.id);
      ids.insert(0, event.id);
    }

    final imageCollections = <String, Set<String>>{};
    for (final entry in collectionImages.entries) {
      for (final imageId in entry.value) {
        imageCollections.putIfAbsent(imageId, () => <String>{}).add(entry.key);
      }
    }

    return _RemoteBookmarkState(
      collectionImages: collectionImages,
      imageCollections: imageCollections,
    );
  }

  Future<void> _pushMissingLocalBookmarks(
    UserState user,
    _RemoteBookmarkState remote,
  ) async {
    final repository = _ref.read(sameEnergyRepositoryProvider);
    for (final image in state.images.values) {
      final remoteCollections =
          remote.imageCollections[image.id] ?? const <String>{};
      for (final collectionId in image.collectionIds) {
        final name = _collectionNameForId(collectionId);
        if (remoteCollections.contains(name)) continue;
        await repository.appendBookmark(
          user,
          imageId: image.id,
          collection: name,
        );
      }
    }
  }

  Future<void> _applyRemoteBookmarkState(_RemoteBookmarkState remote) async {
    final collections = Map<String, SavedCollection>.from(state.collections);
    final images = Map<String, SavedImageItem>.from(state.images);

    for (final imageId in remote.imageCollections.keys) {
      if (images.containsKey(imageId)) continue;
      final hydrated = await _hydrateRemoteImage(imageId);
      images[imageId] = hydrated;
    }

    for (final entry in remote.collectionImages.entries) {
      final collectionName = entry.key;
      final collectionId =
          _findCollectionIdByName(collectionName) ??
          await createCollection(collectionName);
      collections
        ..clear()
        ..addAll(state.collections);
      final existing =
          state.collections[collectionId] ?? collections[collectionId];
      if (existing == null) continue;
      final localTail = existing.imageIds
          .where((id) => !entry.value.contains(id))
          .where(
            (id) => images[id]?.collectionIds.contains(collectionId) ?? false,
          )
          .toList();
      collections[collectionId] = existing.copyWith(
        imageIds: [...entry.value, ...localTail],
      );
    }

    for (final entry in remote.imageCollections.entries) {
      final collectionIds = entry.value
          .map(_findCollectionIdByName)
          .whereType<String>()
          .toSet();
      final existing = images[entry.key];
      if (existing == null) continue;
      images[entry.key] = existing.copyWith(collectionIds: collectionIds);
    }

    state = state.copyWith(collections: collections, images: images);
    await _persist();
  }

  Future<SavedImageItem> _hydrateRemoteImage(String imageId) async {
    final repository = _ref.read(sameEnergyRepositoryProvider);
    final info = await repository.getImageInfo(imageId);
    final resolved = info ?? SameImage(id: imageId);
    final imageUrl = resolved.displayThumbnailUrl.isNotEmpty
        ? resolved.displayThumbnailUrl
        : '${Endpoints.apiBase}${Endpoints.thumbnailById(imageId)}';
    return SavedImageItem(
      id: imageId,
      imageUrl: imageUrl,
      thumbnailUrl: imageUrl,
      sourceUrl: resolved.sourceUrl ?? resolved.postUrl,
      savedAt: DateTime.now(),
      collectionIds: const <String>{},
    );
  }

  String _collectionNameForId(String collectionId) {
    return state.collections[collectionId]?.name ?? uncategorizedCollectionName;
  }

  String? _normalizedCollectionName(String? collectionName) {
    final trimmed = collectionName?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

class _RemoteBookmarkState {
  const _RemoteBookmarkState({
    required this.collectionImages,
    required this.imageCollections,
  });

  final Map<String, List<String>> collectionImages;
  final Map<String, Set<String>> imageCollections;
}
