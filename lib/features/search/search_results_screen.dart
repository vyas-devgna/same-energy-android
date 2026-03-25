import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

import '../../core/api/models/image_model.dart';
import '../../core/settings/app_settings_provider.dart';
import '../../core/storage/preferences_storage.dart';
import '../../core/telemetry/clickstream_service.dart';
import '../collections/collection_picker_sheet.dart';
import '../collections/collections_provider.dart';
import '../image_detail/image_detail_screen.dart';
import '../../shared/widgets/image_grid.dart';
import '../../shared/widgets/search_bar.dart';
import '../../shared/widgets/top_app_bar.dart';
import 'search_provider.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String? imageId;
  final String? secondaryImageId;
  final String? query;
  final int requestToken;

  const SearchResultsScreen({
    super.key,
    this.imageId,
    this.secondaryImageId,
    this.query,
    this.requestToken = 0,
  });

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  bool _uploading = false;
  double _uploadProgress = 0;
  bool _refreshing = false;

  // Multi-select state
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  // Search history
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _searchHistory = PreferencesStorage.getSearchHistory();
  }

  bool get _hasActiveSearch =>
      (widget.imageId != null && widget.imageId!.isNotEmpty) ||
      (widget.secondaryImageId != null && widget.secondaryImageId!.isNotEmpty) ||
      (widget.query != null && widget.query!.isNotEmpty);

  bool get _hasActiveImage =>
      widget.imageId != null && widget.imageId!.isNotEmpty;

  void _onSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _addToHistory(trimmed);
    ClickstreamService().trackSearch([], trimmed, 'first');
    // Free-text searches from Search tab should not reuse stale image IDs.
    context.go(
      Uri(
        path: '/search',
        queryParameters: {
          'q': trimmed,
          'rt': DateTime.now().microsecondsSinceEpoch.toString(),
        },
      ).toString(),
    );
  }

  void _addToHistory(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _searchHistory.remove(trimmed);
    _searchHistory.insert(0, trimmed);
    if (_searchHistory.length > 20) {
      _searchHistory = _searchHistory.sublist(0, 20);
    }
    PreferencesStorage.setSearchHistory(_searchHistory);
    setState(() {});
  }

  void _clearHistory() {
    setState(() => _searchHistory.clear());
    PreferencesStorage.setSearchHistory([]);
  }

  void _onImagePicked(PickedSearchImage picked) async {
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });
    try {
      final imageFile = File(picked.file.path);
      final hash = await uploadImageForSearch(
        ref,
        imageFile,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _uploadProgress = progress.clamp(0.0, 1.0));
        },
      );
      if (!mounted) return;
      final hasActiveImage =
          widget.imageId != null && widget.imageId!.isNotEmpty;
      final params = <String, String>{'i': hash};

      if (hasActiveImage) {
        if (picked.mode == SearchImageMode.together) {
          params['i2'] = hash;
          params['i'] = widget.imageId!;
        }
        if (picked.query.isNotEmpty) {
          params['q'] = picked.query;
        }
      } else if (picked.mode == SearchImageMode.together &&
          picked.query.isNotEmpty) {
        params['q'] = picked.query;
      }

      if (hasActiveImage && picked.mode != SearchImageMode.together) {
        params['i'] = hash;
      }
      params['rt'] = DateTime.now().microsecondsSinceEpoch.toString();
      context.go(Uri(path: '/search', queryParameters: params).toString());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  void _openDetail(List<SameImage> images, int index) {
    if (_selectionMode) {
      _toggleSelection(images[index].id);
      return;
    }
    final image = images[index];
    ClickstreamService().trackExpand(
      'search',
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

    // Download and share images
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
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission Required'),
          content: const Text('To download images, please grant gallery access in settings.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (shouldOpenSettings == true) {
        await openAppSettings();
      }
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

  Future<void> _refreshResults(SearchQuery query) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      ref.invalidate(searchResultsProvider(query));
      await ref.read(searchResultsProvider(query).future);
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final savedIds = ref.watch(savedItemsProvider).images.keys.toSet();
    final settings = ref.watch(appSettingsProvider);

    if (!_hasActiveSearch) {
      return _buildDiscovery(isDark, accent, savedIds, settings);
    }

    final searchQuery = SearchQuery(
      imageId: widget.imageId,
      secondaryImageId: widget.secondaryImageId,
      text: widget.query,
      count: 100,
      nsfw: settings.safeSearchEnabled,
      requestToken: widget.requestToken,
    );
    final searchAsync = ref.watch(searchResultsProvider(searchQuery));

    return Scaffold(
      appBar: SameEnergyTopAppBar(
        title: _selectionMode
            ? '${_selectedIds.length} selected'
            : (widget.query ?? 'Results'),
        actions: _selectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelectionMode,
                ),
              ]
            : [],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              AppSearchBar(
                onSearch: _onSearch,
                onImagePicked: _onImagePicked,
                initialQuery: widget.query,
                hasActiveImage: _hasActiveImage,
                showUploadProgress: _uploading,
                uploadProgress: _uploadProgress,
              ),
              Expanded(
                child: searchAsync.when(
                  data: (images) {
                    if (images.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 56,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No results found',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () => _refreshResults(searchQuery),
                      child: ImageGrid(
                        images: images,
                        bookmarkedIds: savedIds,
                        selectionMode: _selectionMode,
                        selectedIds: _selectedIds,
                        onImageTap: (image, index) =>
                            _openDetail(images, index),
                        onImageLongPress: _onLongPress,
                        onQuickSave: (image, _) => _openSaveSheet(image),
                        onDoubleTap: (image, _) {
                          ref
                              .read(savedItemsProvider.notifier)
                              .toggleQuickSave(image);
                        },
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          color: Colors.grey,
                          size: 52,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Search failed',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(
                            searchResultsProvider(searchQuery),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                  _FloatingActionPill(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    accent: accent,
                    isDark: isDark,
                    onTap: () {
                      final images = searchAsync.valueOrNull ?? [];
                      _shareSelected(images);
                    },
                  ),
                  const SizedBox(height: 10),
                  _FloatingActionPill(
                    icon: Icons.download_outlined,
                    label: 'Download',
                    accent: accent,
                    isDark: isDark,
                    onTap: () {
                      final images = searchAsync.valueOrNull ?? [];
                      _downloadSelected(images);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiscovery(
    bool isDark,
    Color accent,
    Set<String> savedIds,
    AppSettingsState settings,
  ) {
    final discoveryAsync = ref.watch(searchDiscoveryProvider);

    return Scaffold(
      appBar: const SameEnergyTopAppBar(title: 'Search'),
      body: Column(
        children: [
          AppSearchBar(
            onSearch: _onSearch,
            onImagePicked: _onImagePicked,
            hasActiveImage: _hasActiveImage,
            showUploadProgress: _uploading,
            uploadProgress: _uploadProgress,
          ),
          Expanded(
            child: discoveryAsync.when(
              data: (discovery) {
                return ListView(
                  padding: const EdgeInsets.only(bottom: 90),
                  children: [
                    // Search history
                    if (_searchHistory.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            Text(
                              'Recent searches',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _clearHistory,
                              child: Text(
                                'Clear',
                                style: TextStyle(fontSize: 12, color: accent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _searchHistory.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final q = _searchHistory[index];
                            return ActionChip(
                              label: Text(
                                q,
                                style: const TextStyle(fontSize: 13),
                              ),
                              onPressed: () => _onSearch(q),
                              avatar: const Icon(Icons.history, size: 14),
                              side: BorderSide(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Collections
                    if (discovery.recommendedCollections.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          'Explore collections',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: discovery.recommendedCollections.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final feed =
                                discovery.recommendedCollections[index];
                            return ActionChip(
                              label: Text(feed.name),
                              onPressed: () => _onSearch(feed.name),
                              side: BorderSide(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    // Trending
                    if (discovery.trendingImages.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Trending now',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 160,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: discovery.trendingImages.length.clamp(
                            0,
                            12,
                          ),
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final image = discovery.trendingImages[index];
                            return GestureDetector(
                              onTap: () {
                                context.push(
                                  '/i/${image.id}',
                                  extra: ImageDetailArgs(
                                    images: discovery.trendingImages,
                                    initialIndex: index,
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: CachedNetworkImage(
                                  imageUrl: image.displayThumbnailUrl,
                                  width: 120,
                                  height: 160,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    width: 120,
                                    color: isDark
                                        ? const Color(0xFF1A2026)
                                        : const Color(0xFFE8E4DB),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    width: 120,
                                    color: isDark
                                        ? const Color(0xFF1A2026)
                                        : const Color(0xFFE8E4DB),
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => Center(
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(searchDiscoveryProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
            ),
          ),
        ],
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
