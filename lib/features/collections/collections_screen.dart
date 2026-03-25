import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_theme.dart';
import '../../core/api/models/image_model.dart';
import '../../core/settings/app_settings_provider.dart';
import '../image_detail/image_detail_screen.dart';
import '../../shared/widgets/image_tile.dart';
import '../../shared/widgets/top_app_bar.dart';
import 'collection_lock_sheet.dart';
import 'collections_provider.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedItemsProvider);
    final notifier = ref.read(savedItemsProvider.notifier);
    final collections = saved.orderedCollections;
    final allImages = saved.publicOrderedImages;
    final savedIds = saved.images.keys.toSet();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBootstrapping =
        saved.isLoading && saved.collections.length <= 1 && allImages.isEmpty;

    return Scaffold(
      appBar: const SameEnergyTopAppBar(title: 'Saved'),
      body: isBootstrapping
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  height: 134,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: collections.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _NewCollectionCard(
                          onTap: () => _createCollection(context, ref),
                        );
                      }
                      final collection = collections[index - 1];
                      final collectionItems = saved.imagesForCollection(
                        collection.id,
                      );
                      final coverImages = _coverImages(
                        collection,
                        collectionItems,
                      );
                      return _CollectionCard(
                        name: collection.name,
                        count: collectionItems.length,
                        images: coverImages,
                        locked:
                            collection.isPrivate &&
                            !notifier.isCollectionUnlocked(collection.id),
                        onTap: () => _openCollection(context, ref, collection),
                      );
                    },
                  ),
                ),
                if (saved.errorMessage != null)
                  _SavedCollectionsErrorState(
                    message: saved.errorMessage!,
                    onRetry: notifier.refreshFromServer,
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: notifier.refreshFromServer,
                    child: allImages.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  8,
                                ),
                                child: Text(
                                  'All saved',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 80),
                              const _SavedEmptyState(),
                            ],
                          )
                        : _AllSavedGrid(
                            allImages: allImages,
                            savedIds: savedIds,
                            isDark: isDark,
                            onQuickSave: (image) =>
                                notifier.toggleQuickSave(image),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _createCollection(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    var isPrivate = false;
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Collection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Collection name'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isPrivate,
                onChanged: (value) {
                  setDialogState(() => isPrivate = value);
                },
                title: const Text('Private'),
                subtitle: const Text('Require PIN to access'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (!context.mounted) return;
    if (value == null || value.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection name cannot be empty.')),
      );
      return;
    }
    if (isPrivate) {
      final configured = await ensureCollectionLockPinConfigured(context, ref);
      if (!context.mounted) return;
      if (!configured) return;
    }
    HapticFeedback.lightImpact();
    String id;
    try {
      id = await ref
          .read(savedItemsProvider.notifier)
          .createCollection(value, isPrivate: isPrivate);
    } on StateError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
      return;
    }
    if (!context.mounted) return;
    context.push('/saved/collection/$id');
  }

  Future<void> _openCollection(
    BuildContext context,
    WidgetRef ref,
    SavedCollection collection,
  ) async {
    final notifier = ref.read(savedItemsProvider.notifier);
    if (collection.isPrivate && !notifier.isCollectionUnlocked(collection.id)) {
      final unlocked = await authenticateCollectionUnlock(
        context,
        ref,
        reason: 'Unlock ${collection.name}',
      );
      if (!unlocked || !context.mounted) return;
      notifier.unlockCollectionSession(collection.id);
    }
    if (!context.mounted) return;
    context.push('/saved/collection/${collection.id}');
  }

  List<SameImage> _coverImages(
    SavedCollection collection,
    List<SavedImageItem> items,
  ) {
    if (items.isEmpty) return const [];
    final ordered = <SavedImageItem>[];
    if (collection.coverImageId != null) {
      final cover = items.where((item) => item.id == collection.coverImageId);
      ordered.addAll(cover);
    }
    ordered.addAll(items.where((item) => item.id != collection.coverImageId));
    return ordered.take(4).map((item) => item.toSameImage()).toList();
  }
}

class _SavedEmptyState extends StatelessWidget {
  const _SavedEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.bookmark_border, size: 72, color: Colors.grey),
          SizedBox(height: 12),
          Text('Nothing saved yet. Tap save on any image to bookmark it.'),
        ],
      ),
    );
  }
}

class _SavedCollectionsErrorState extends StatelessWidget {
  const _SavedCollectionsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withValues(alpha: 0.45)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              softWrap: true,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.red[200]
                    : Colors.red[900],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewCollectionCard extends StatelessWidget {
  const _NewCollectionCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 24),
            SizedBox(height: 6),
            Text(
              'New',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.name,
    required this.count,
    required this.images,
    required this.locked,
    required this.onTap,
  });

  final String name;
  final int count;
  final List<SameImage> images;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 86,
              decoration: BoxDecoration(
                color: SameEnergyTheme.surfaceFor(context, elevated: true),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: 4,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 1,
                          mainAxisSpacing: 1,
                        ),
                    itemBuilder: (context, index) {
                      if (index >= images.length || locked) {
                        return Container(
                          color: isDark
                              ? const Color(0xFF1A2026)
                              : const Color(0xFFE8E4DB),
                        );
                      }
                      final image = images[index];
                      return CachedNetworkImage(
                        imageUrl: image.displayThumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: isDark
                              ? const Color(0xFF1A2026)
                              : const Color(0xFFE8E4DB),
                        ),
                      );
                    },
                  ),
                  if (locked)
                    Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.lock_outline,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (locked) const Icon(Icons.lock_outline, size: 14),
              ],
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllSavedGrid extends ConsumerWidget {
  const _AllSavedGrid({
    required this.allImages,
    required this.savedIds,
    required this.isDark,
    required this.onQuickSave,
  });

  final List<SavedImageItem> allImages;
  final Set<String> savedIds;
  final bool isDark;
  final void Function(SameImage image) onQuickSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final crossAxisCount = isLandscape
        ? (settings.gridColumns + 1).clamp(2, 4)
        : settings.gridColumns;
    final spacing = settings.imagePadding.toDouble();
    final sameImages = allImages.map((e) => e.toSameImage()).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Text(
              'All saved',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(4),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childCount: sameImages.length,
            itemBuilder: (context, index) {
              final image = sameImages[index];
              return ImageTile(
                image: image,
                heroTag: 'image_${image.id}',
                isBookmarked: savedIds.contains(image.id),
                onTap: () {
                  context.push(
                    '/i/${image.id}',
                    extra: ImageDetailArgs(
                      images: sameImages,
                      initialIndex: index,
                    ),
                  );
                },
                onQuickSave: () => onQuickSave(image),
                onDoubleTap: () => onQuickSave(image),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }
}
