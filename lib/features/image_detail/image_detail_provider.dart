import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/models/image_model.dart';
import '../../core/data/repositories/same_energy_repository_impl.dart';

final imageInfoProvider = FutureProvider.family<SameImage?, String>((
  ref,
  imageId,
) async {
  try {
    final repository = ref.read(sameEnergyRepositoryProvider);
    return await repository.getImageInfo(imageId);
  } catch (_) {
    return null;
  }
});

class SimilarImagesParams {
  final String imageId;
  final int count;
  const SimilarImagesParams({required this.imageId, required this.count});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimilarImagesParams &&
          runtimeType == other.runtimeType &&
          imageId == other.imageId &&
          count == other.count;

  @override
  int get hashCode => Object.hash(imageId, count);
}

final similarImagesProvider =
    FutureProvider.family<List<SameImage>, SimilarImagesParams>((
      ref,
      params,
    ) async {
      try {
        final repository = ref.read(sameEnergyRepositoryProvider);
        final result = await repository.search(
          imageId: params.imageId,
          n: params.count,
        );
        return result.images;
      } catch (_) {
        return [];
      }
    });
