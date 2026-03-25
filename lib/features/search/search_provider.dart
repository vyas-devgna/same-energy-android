import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/models/feed_model.dart';
import '../../core/api/models/image_model.dart';
import '../../core/auth/auth_state.dart';
import '../../core/data/repositories/same_energy_repository_impl.dart';
import '../../core/domain/repositories/same_energy_repository.dart';

final searchResultsProvider =
    FutureProvider.family<List<SameImage>, SearchQuery>((ref, query) async {
      final repository = ref.read(sameEnergyRepositoryProvider);
      final primaryImageId = query.imageId;
      final secondaryImageId = query.secondaryImageId;
      if (secondaryImageId == null || secondaryImageId.isEmpty) {
        final result = await repository.search(
          imageId: primaryImageId,
          text: query.text,
          n: query.count,
          nsfw: query.nsfw,
        );
        return result.images;
      }

      final firstResultFuture = repository.search(
        imageId: primaryImageId,
        text: query.text,
        n: query.count,
        nsfw: query.nsfw,
      );
      final secondResultFuture = repository.search(
        imageId: secondaryImageId,
        text: query.text,
        n: query.count,
        nsfw: query.nsfw,
      );

      final firstResult = await firstResultFuture.catchError((_) {
        return const SearchData(images: []);
      });
      final secondResult = await secondResultFuture.catchError((_) {
        return const SearchData(images: []);
      });
      final merged = mergeSearchResultsIntersectionFirst(
        firstResult.images,
        secondResult.images,
        limit: query.count,
      );
      if (merged.isNotEmpty) return merged;
      // If merge yields empty due one branch failure, fall back to whichever has data.
      if (firstResult.images.isNotEmpty) return firstResult.images;
      if (secondResult.images.isNotEmpty) return secondResult.images;
      throw Exception('Search together failed. Try again.');
    });

final searchDiscoveryProvider = FutureProvider<SearchDiscoveryData>((ref) async {
  final user = ref.read(authStateProvider);
  final repository = ref.read(sameEnergyRepositoryProvider);
  final homepage = await repository.fetchHomepage(user: user);
  return SearchDiscoveryData(
    recommendedCollections: homepage.feeds,
    trendingImages: homepage.images,
  );
});

class SearchDiscoveryData {
  const SearchDiscoveryData({
    required this.recommendedCollections,
    required this.trendingImages,
  });

  final List<FeedCategory> recommendedCollections;
  final List<SameImage> trendingImages;
}

class SearchQuery {
  final String? imageId;
  final String? secondaryImageId;
  final String? text;
  final int count;
  final bool nsfw;
  final int requestToken;

  const SearchQuery({
    this.imageId,
    this.secondaryImageId,
    this.text,
    this.count = 100,
    this.nsfw = true,
    this.requestToken = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchQuery &&
          imageId == other.imageId &&
          secondaryImageId == other.secondaryImageId &&
          text == other.text &&
          count == other.count &&
          nsfw == other.nsfw &&
          requestToken == other.requestToken;

  @override
  int get hashCode => Object.hash(
    imageId,
    secondaryImageId,
    text,
    count,
    nsfw,
    requestToken,
  );
}

List<SameImage> mergeSearchResultsIntersectionFirst(
  List<SameImage> primary,
  List<SameImage> secondary, {
  required int limit,
}) {
  final secondaryIds = secondary.map((image) => image.id).toSet();
  final intersection = primary
      .where((image) => secondaryIds.contains(image.id))
      .toList();
  final intersectionIds = intersection.map((image) => image.id).toSet();
  final primaryTail = primary
      .where((image) => !intersectionIds.contains(image.id))
      .toList();
  final seen = <String>{};
  final merged = <SameImage>[];

  void appendImages(List<SameImage> images) {
    for (final image in images) {
      if (seen.add(image.id)) {
        merged.add(image);
      }
    }
  }

  appendImages(intersection);
  appendImages(primaryTail);
  appendImages(secondary);

  if (limit <= 0 || merged.length <= limit) return merged;
  return merged.take(limit).toList();
}

/// Compute SHA-1 hash of an image file for upload search
Future<String> computeImageHash(File file) async {
  final bytes = await file.readAsBytes();
  final digest = sha1.convert(bytes);
  return digest.toString();
}

Future<String> uploadImageForSearch(
  WidgetRef ref,
  File file, {
  void Function(double progress)? onProgress,
}) async {
  final bytes = await file.readAsBytes();
  final repository = ref.read(sameEnergyRepositoryProvider);
  final contentType = _contentTypeForBytes(bytes);
  final upload = await repository.uploadImage(
    bytes: bytes,
    contentType: contentType,
    onSendProgress: (sent, total) {
      if (onProgress == null) return;
      if (total <= 0) {
        onProgress(0);
        return;
      }
      onProgress(sent / total);
    },
  );
  return upload.imageId;
}

String _contentTypeForBytes(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  // Backend accepts JPEG broadly; use it as safe fallback.
  return 'image/jpeg';
}
