import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../collections/collection_picker_sheet.dart';
import '../../features/collections/collections_provider.dart';
import '../../features/image_detail/image_detail_screen.dart';
import '../../shared/widgets/image_grid.dart';
import '../../shared/widgets/top_app_bar.dart';
import 'feed_provider.dart';

class FeedScreen extends ConsumerWidget {
  final String feedId;

  const FeedScreen({super.key, required this.feedId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(feedImagesProvider(feedId));
    final savedIds = ref.watch(savedItemsProvider).images.keys.toSet();

    return Scaffold(
      appBar: SameEnergyTopAppBar(title: feedId),
      body: imagesAsync.when(
        data: (images) => ImageGrid(
          images: images,
          bookmarkedIds: savedIds,
          onImageTap: (_, index) {
            context.push(
              '/i/${images[index].id}',
              extra: ImageDetailArgs(images: images, initialIndex: index),
            );
          },
          onQuickSave: (image, _) async {
            final result = await showCollectionPickerSheet(context, image: image);
            if (!context.mounted || result == null) return;
            final names = result.selectedCollectionNames.join(', ');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result.nextCollectionIds.isEmpty
                      ? 'Removed from saved'
                      : (names.isEmpty ? 'Saved' : 'Saved to $names'),
                ),
              ),
            );
          },
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, stackTrace) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(feedImagesProvider(feedId)),
            child: const Text('Retry'),
          ),
        ),
      ),
    );
  }
}
