import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/models/image_model.dart';
import '../../core/data/repositories/same_energy_repository_impl.dart';

final feedImagesProvider = FutureProvider.family<List<SameImage>, String>((
  ref,
  feedId,
) async {
  try {
    final repository = ref.read(sameEnergyRepositoryProvider);
    return await repository.fetchFeed(feedId);
  } catch (_) {}
  return [];
});
