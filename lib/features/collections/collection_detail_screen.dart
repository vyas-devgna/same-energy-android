import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

import '../../core/api/models/image_model.dart';
import '../../core/settings/app_settings_provider.dart';
import '../image_detail/image_detail_screen.dart';
import '../../shared/widgets/image_tile.dart';
import '../../shared/widgets/glass_background.dart';
import '../../shared/widgets/top_app_bar.dart';
import 'collection_lock_sheet.dart';
import 'collections_provider.dart';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  bool _unlockChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCollectionUnlocked();
    });
  }

  SavedCollection? get _collection =>
      ref.read(savedItemsProvider).collections[widget.collectionId];

  List<SavedImageItem> get _items =>
      ref.read(savedItemsProvider).imagesForCollection(widget.collectionId);

  Future<void> _ensureCollectionUnlocked() async {
    if (_unlockChecked) return;
    _unlockChecked = true;
    final collection = _collection;
    if (collection == null || !collection.isPrivate) return;
    final notifier = ref.read(savedItemsProvider.notifier);
    if (notifier.isCollectionUnlocked(collection.id)) return;
    final unlocked = await authenticateCollectionUnlock(
      context,
      ref,
      reason: 'Unlock ${collection.name}',
    );
    if (!mounted) return;
    if (!unlocked) {
      context.pop();
      return;
    }
    notifier.unlockCollectionSession(collection.id);
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _onLongPress(SameImage image, int index) {
    HapticFeedback.mediumImpact();
    if (!_selectionMode) {
      setState(() {
        _selectionMode = true;
        _selectedIds.clear();
        _selectedIds.add(image.id);
      });
    } else {
      _toggleSelection(image.id);
    }
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds.addAll(_items.map((e) => e.id));
    });
  }

  Future<void> _removeSelected() async {
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove images'),
        content: Text('Remove $count image(s) from this collection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    for (final id in _selectedIds) {
      await ref
          .read(savedItemsProvider.notifier)
          .removeImageFromCollection(id, widget.collectionId);
    }
    HapticFeedback.lightImpact();
    _exitSelection();
  }

  Future<void> _shareSelected() async {
    if (_selectedIds.isEmpty) return;
    final links = _selectedIds
        .map((id) => 'https://same.energy/i/$id')
        .join('\n');
    final option = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text('Share ${_selectedIds.length} image(s)'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Share links'),
              onTap: () => Navigator.pop(ctx, 'link'),
            ),
            ListTile(
              leading: const Icon(Icons.layers_outlined),
              title: const Text('Share both'),
              onTap: () => Navigator.pop(ctx, 'both'),
            ),
          ],
        ),
      ),
    );
    if (option == null || !mounted) return;

    if (option == 'link') {
      await share_plus.Share.share(links);
      _exitSelection();
      return;
    }

    final files = <share_plus.XFile>[];
    final tempPaths = <String>[];
    for (final id in _selectedIds) {
      final matching = _items.where((e) => e.id == id);
      if (matching.isEmpty) continue;
      final item = matching.first;
      final url = item.thumbnailUrl;
      if (url.isEmpty) continue;
      try {
        final response = await Dio().get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        final tempFile = File('${Directory.systemTemp.path}/${id}_share.jpg');
        await tempFile.writeAsBytes(response.data ?? []);
        tempPaths.add(tempFile.path);
        files.add(share_plus.XFile(tempFile.path));
      } catch (_) {}
    }
    if (files.isNotEmpty) {
      await share_plus.Share.shareXFiles(
        files,
        text: option == 'both' ? links : null,
      );
    }
    for (final path in tempPaths) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    _exitSelection();
  }

  Future<void> _downloadSelected() async {
    if (_selectedIds.isEmpty) return;
    HapticFeedback.lightImpact();
    final status = await Permission.photos.request();
    if (!mounted) return;
    if (!status.isGranted && !status.isLimited) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gallery permission denied')),
      );
      return;
    }

    int downloaded = 0;
    for (final id in _selectedIds) {
      final matching = _items.where((e) => e.id == id);
      if (matching.isEmpty) continue;
      final item = matching.first;
      final url = item.thumbnailUrl;
      if (url.isEmpty) continue;
      try {
        final response = await Dio().get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        final tempFile = File('${Directory.systemTemp.path}/${id}_dl.jpg');
        await tempFile.writeAsBytes(response.data ?? []);
        await Gal.putImage(tempFile.path);
        await tempFile.delete();
        downloaded++;
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded $downloaded image(s)')),
      );
    }
    _exitSelection();
  }

  void _showCollectionActions() async {
    final collection = _collection;
    if (collection == null) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _renameCollection();
              },
            ),
            ListTile(
              leading: Icon(
                collection.isPrivate
                    ? Icons.lock_open_outlined
                    : Icons.lock_outline,
              ),
              title: Text(
                collection.isPrivate ? 'Make public' : 'Make private',
              ),
              subtitle: collection.isPrivate
                  ? null
                  : const Text('Requires PIN to access'),
              onTap: () {
                Navigator.pop(ctx);
                _togglePrivacy();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete collection',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _deleteCollection();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameCollection() async {
    final collection = _collection;
    if (collection == null) return;
    final controller = TextEditingController(text: collection.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || !mounted) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection name cannot be empty.')),
      );
      return;
    }
    try {
      await ref
          .read(savedItemsProvider.notifier)
          .renameCollection(widget.collectionId, trimmed);
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message.toString())),
      );
    }
  }

  Future<void> _togglePrivacy() async {
    final collection = _collection;
    if (collection == null) return;
    if (!collection.isPrivate) {
      final configured = await ensureCollectionLockPinConfigured(context, ref);
      if (!mounted || !configured) return;
    }
    ref
        .read(savedItemsProvider.notifier)
        .setCollectionPrivacy(widget.collectionId, !collection.isPrivate);
  }

  Future<void> _deleteCollection() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete collection'),
        content: const Text(
          'This will permanently delete the collection. Saved images will remain in your library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    ref.read(savedItemsProvider.notifier).deleteCollection(widget.collectionId);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedItemsProvider);
    final collection = saved.collections[widget.collectionId];
    final items = saved.imagesForCollection(widget.collectionId);
    final savedIds = saved.images.keys.toSet();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final settings = ref.watch(appSettingsProvider);
    final crossAxisCount = settings.gridColumns;
    final spacing = settings.imagePadding.toDouble();
    final sameImages = items.map((e) => e.toSameImage()).toList();

    if (collection == null) {
      return Scaffold(
        appBar: const SameEnergyTopAppBar(title: 'Collection'),
        body: const Center(child: Text('Collection not found.')),
      );
    }

    return Scaffold(
      appBar: SameEnergyTopAppBar(
        title: _selectionMode
            ? '${_selectedIds.length} selected'
            : collection.name,
        actions: _selectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: _selectAll,
                  tooltip: 'Select all',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelection,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: _showCollectionActions,
                ),
              ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: SameEnergyGlassBackground()),
          sameImages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This collection is empty',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
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
                            selectionMode: _selectionMode,
                            isSelected: _selectedIds.contains(image.id),
                            onTap: () {
                              if (_selectionMode) {
                                _toggleSelection(image.id);
                              } else {
                                context.push(
                                  '/i/${image.id}',
                                  extra: ImageDetailArgs(
                                    images: sameImages,
                                    initialIndex: index,
                                  ),
                                );
                              }
                            },
                            onLongPress: () => _onLongPress(image, index),
                            onDoubleTap: () {
                              ref
                                  .read(savedItemsProvider.notifier)
                                  .toggleQuickSave(image);
                            },
                          );
                        },
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 90)),
                  ],
                ),
          // Multi-select action bar
          if (_selectionMode && _selectedIds.isNotEmpty)
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 90,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionPill(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    accent: accent,
                    isDark: isDark,
                    onTap: _shareSelected,
                  ),
                  const SizedBox(height: 10),
                  _ActionPill(
                    icon: Icons.download_outlined,
                    label: 'Download',
                    accent: accent,
                    isDark: isDark,
                    onTap: _downloadSelected,
                  ),
                  const SizedBox(height: 10),
                  _ActionPill(
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    accent: Colors.redAccent,
                    isDark: isDark,
                    onTap: _removeSelected,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: isDark
              ? Colors.black.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
