import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../core/api/models/image_model.dart';
import '../../core/settings/app_settings_provider.dart';
import 'image_tile.dart';

class ImageGrid extends ConsumerWidget {
  const ImageGrid({
    super.key,
    required this.images,
    this.bookmarkedIds = const {},
    this.selectionMode = false,
    this.selectedIds = const {},
    this.onImageTap,
    this.onImageLongPress,
    this.onQuickSave,
    this.onDoubleTap,
    this.scrollController,
    this.isLoading = false,
    this.padding,
  });

  final List<SameImage> images;
  final Set<String> bookmarkedIds;
  final bool selectionMode;
  final Set<String> selectedIds;
  final void Function(SameImage image, int index)? onImageTap;
  final void Function(SameImage image, int index)? onImageLongPress;
  final void Function(SameImage image, int index)? onQuickSave;
  final void Function(SameImage image, int index)? onDoubleTap;
  final ScrollController? scrollController;
  final bool isLoading;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final crossAxisCount = isLandscape
        ? (settings.gridColumns + 1).clamp(2, 4)
        : settings.gridColumns;
    final spacing = settings.imagePadding.toDouble();

    return CustomScrollView(
      controller: scrollController,
      cacheExtent: 300, // Reduce off-screen rendering for performance
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: padding ?? const EdgeInsets.all(4),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              return RepaintBoundary(
                child: ImageTile(
                  image: image,
                  heroTag: 'image_${image.id}',
                  isBookmarked: bookmarkedIds.contains(image.id),
                  isSelected: selectedIds.contains(image.id),
                  selectionMode: selectionMode,
                  onTap: () => onImageTap?.call(image, index),
                  onLongPress: () => onImageLongPress?.call(image, index),
                  onQuickSave: onQuickSave != null
                      ? () => onQuickSave!(image, index)
                      : null,
                  onDoubleTap: onDoubleTap != null
                      ? () => onDoubleTap!(image, index)
                      : null,
                ),
              );
            },
          ),
        ),
        if (isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        // Bottom padding for floating nav bar
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }
}
