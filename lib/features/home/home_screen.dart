import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

import '../../core/api/models/image_model.dart';
import '../../core/telemetry/clickstream_service.dart';
import '../collections/collection_picker_sheet.dart';
import '../collections/collections_provider.dart';
import '../image_detail/image_detail_screen.dart';
import '../../shared/widgets/feed_chip_row.dart';
import '../../shared/widgets/image_grid.dart';
import '../../shared/widgets/top_app_bar.dart';
import 'home_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Multi-select
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _openDetail(List<SameImage> images, int index) {
    if (_selectionMode) {
      _toggleSelection(images[index].id);
      return;
    }
    final image = images[index];
    ClickstreamService().trackExpand(
      'home',
      [],
      image.id,
      'https://same.energy/',
    );
    context.push(
      '/i/${image.id}',
      extra: ImageDetailArgs(images: images, initialIndex: index),
    );
  }

  void _onLongPress(SameImage image, int index) {
    if (!_selectionMode) {
      HapticFeedback.mediumImpact();
      setState(() {
        _selectionMode = true;
        _selectedIds.clear();
        _selectedIds.add(image.id);
      });
    } else {
      _toggleSelection(image.id);
    }
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

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _shareSelected(List<SameImage> allImages) async {
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
      _exitSelectionMode();
      return;
    }

    final files = <share_plus.XFile>[];
    final tempPaths = <String>[];
    for (final id in _selectedIds) {
      final image = allImages.firstWhere(
        (img) => img.id == id,
        orElse: () => SameImage(id: id),
      );
      final url = image.displayThumbnailUrl.isNotEmpty
          ? image.displayThumbnailUrl
          : 'https://imageapi.same.energy/thumbnail?id=$id';
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
    _exitSelectionMode();
  }

  Future<void> _downloadSelected(List<SameImage> allImages) async {
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
      final image = allImages.firstWhere(
        (img) => img.id == id,
        orElse: () => SameImage(id: id),
      );
      final url = image.displayThumbnailUrl.isNotEmpty
          ? image.displayThumbnailUrl
          : 'https://imageapi.same.energy/thumbnail?id=$id';
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
    _exitSelectionMode();
  }

  Future<void> _openSaveSheet(SameImage image) async {
    HapticFeedback.lightImpact();
    final result = await showCollectionPickerSheet(context, image: image);
    if (!mounted || result == null) return;
    final names = result.selectedCollectionNames.join(', ');
    final removed = result.nextCollectionIds.isEmpty;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed
              ? 'Removed from saved'
              : (names.isEmpty ? 'Saved' : 'Saved to $names'),
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await ref
                .read(savedItemsProvider.notifier)
                .saveImageToCollections(
                  result.image,
                  result.previousCollectionIds,
                );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeAsync = ref.watch(homeControllerProvider);
    final savedIds = ref.watch(savedItemsProvider).images.keys.toSet();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: SameEnergyTopAppBar(
        title: _selectionMode
            ? '${_selectedIds.length} selected'
            : 'same.energy',
        showLogo: !_selectionMode,
        actions: _selectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelectionMode,
                ),
              ]
            : [],
      ),
      body: homeAsync.when(
        data: (home) {
          final feedNames = ['All', ...home.feeds.map((f) => f.name)];
          final selectedFeed = home.selectedFeed ?? 'All';

          return Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: FeedChipRow(
                      feeds: feedNames,
                      selectedFeed: selectedFeed,
                      onFeedSelected: (feed) {
                        ClickstreamService().trackSelectFeed(feed);
                        if (feed == 'All') {
                          ref
                              .read(homeControllerProvider.notifier)
                              .selectFeed(null);
                        } else {
                          ref
                              .read(homeControllerProvider.notifier)
                              .selectFeed(feed);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () =>
                          ref.read(homeControllerProvider.notifier).refresh(),
                      child: home.images.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 120),
                                Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.cloud_off,
                                        color: Colors.grey.shade400,
                                        size: 52,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'No images available. Pull to refresh.',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ImageGrid(
                              images: home.images,
                              bookmarkedIds: savedIds,
                              selectionMode: _selectionMode,
                              selectedIds: _selectedIds,
                              onImageTap: (image, index) =>
                                  _openDetail(home.images, index),
                              onImageLongPress: _onLongPress,
                              onQuickSave: (image, _) => _openSaveSheet(image),
                              onDoubleTap: (image, _) {
                                ref
                                    .read(savedItemsProvider.notifier)
                                    .toggleQuickSave(image);
                              },
                            ),
                    ),
                  ),
                ],
              ),
              if (_selectionMode && _selectedIds.isNotEmpty)
                Positioned(
                  right: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 90,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FloatingActionPill(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        accent: accent,
                        isDark: isDark,
                        onTap: () => _shareSelected(home.images),
                      ),
                      const SizedBox(height: 10),
                      _FloatingActionPill(
                        icon: Icons.download_outlined,
                        label: 'Download',
                        accent: accent,
                        isDark: isDark,
                        onTap: () => _downloadSelected(home.images),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Colors.grey, size: 52),
              const SizedBox(height: 10),
              Text(
                'Something went wrong. Tap to retry.',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.read(homeControllerProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingActionPill extends StatelessWidget {
  const _FloatingActionPill({
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
