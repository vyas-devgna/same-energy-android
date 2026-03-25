import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/endpoints.dart';
import '../../core/api/models/image_model.dart';
import '../../core/design/app_theme.dart';
import '../../core/settings/app_settings_provider.dart';
import '../collections/collection_picker_sheet.dart';
import '../collections/collections_provider.dart';
import '../search/search_provider.dart';
import '../../shared/widgets/glass_background.dart';
import 'image_detail_provider.dart';

class ImageDetailArgs {
  final List<SameImage> images;
  final int initialIndex;

  const ImageDetailArgs({required this.images, required this.initialIndex});
}

class ImageDetailScreen extends ConsumerStatefulWidget {
  final String imageId;
  final ImageDetailArgs? args;

  const ImageDetailScreen({super.key, required this.imageId, this.args});

  @override
  ConsumerState<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends ConsumerState<ImageDetailScreen> {
  late final PageController _pageController;
  late List<SameImage> _images;
  int _currentIndex = 0;
  final TransformationController _transformController =
      TransformationController();
  double? _downloadProgress;
  String? _operationLabel;

  // Similar images state
  List<SameImage> _similarImages = [];
  bool _loadingSimilar = false;
  bool _hasMoreSimilar = true;
  static const _similarPageSize = 40;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _similarSeedHistory = <String>{};

  @override
  void initState() {
    super.initState();
    _images = widget.args?.images.isNotEmpty == true
        ? widget.args!.images
        : [SameImage(id: widget.imageId)];
    final passedIndex = widget.args?.initialIndex ?? 0;
    final initialIndex = _images.indexWhere((img) => img.id == widget.imageId);
    _currentIndex = initialIndex >= 0
        ? initialIndex
        : passedIndex.clamp(0, _images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _scrollController.addListener(_onScroll);
    _loadSimilar();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  SameImage get _currentImage => _images[_currentIndex];

  String _resolvedUrl(SameImage image) {
    final url = image.displayThumbnailUrl;
    if (url.isNotEmpty) return url;
    return '${Endpoints.apiBase}${Endpoints.thumbnailById(image.id)}';
  }

  bool get _isZoomed => _transformController.value.getMaxScaleOnAxis() > 1.01;

  void _onDoubleTap() {
    if (_isZoomed) {
      _transformController.value = Matrix4.identity();
      return;
    }
    _transformController.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMoreSimilar();
    }
  }

  Future<void> _loadSimilar() async {
    if (_loadingSimilar) return;
    setState(() {
      _loadingSimilar = true;
      _similarImages = [];
      _hasMoreSimilar = true;
      _similarSeedHistory
        ..clear()
        ..add(_currentImage.id);
    });
    try {
      final results = await ref.read(
        similarImagesProvider(
          SimilarImagesParams(
            imageId: _currentImage.id,
            count: _similarPageSize,
          ),
        ).future,
      );
      if (mounted) {
        setState(() {
          _similarImages = _mergeUniqueSimilar([], results);
          _loadingSimilar = false;
          _hasMoreSimilar = _hasMoreData(results, _similarPageSize);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSimilar = false);
    }
  }

  Future<void> _loadMoreSimilar() async {
    if (_loadingSimilar || !_hasMoreSimilar) return;
    setState(() => _loadingSimilar = true);
    try {
      final previousLength = _similarImages.length;
      final pivotSeed = _nextPivotSeed(_similarImages) ?? _currentImage.id;
      final pivotResults = await ref.read(
        similarImagesProvider(
          SimilarImagesParams(imageId: pivotSeed, count: _similarPageSize),
        ).future,
      );
      if (!mounted) return;
      final merged = _mergeUniqueSimilar(
        _similarImages,
        pivotResults.where((image) => image.id != _currentImage.id).toList(),
      );
      final addedNew = merged.length > previousLength;
      setState(() {
        _similarImages = merged;
        _loadingSimilar = false;
        _hasMoreSimilar = addedNew;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSimilar = false);
    }
  }

  String? _nextPivotSeed(List<SameImage> images) {
    for (int index = images.length - 1; index >= 0; index--) {
      final id = images[index].id;
      if (_similarSeedHistory.add(id)) {
        return id;
      }
    }
    return null;
  }

  bool _looksLikeUrl(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.contains('://');
  }

  String? _cleanText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (_looksLikeUrl(trimmed)) return null;
    return trimmed;
  }

  String? _cleanSourceLabel(SameImage image) {
    return _cleanText(image.source);
  }

  Future<Uint8List> _downloadBytes(String url) async {
    final response = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        if (total <= 0 || !mounted) return;
        setState(() => _downloadProgress = received / total);
      },
    );
    setState(() => _downloadProgress = null);
    return Uint8List.fromList(response.data ?? const []);
  }

  Future<void> _downloadCurrent() async {
    HapticFeedback.lightImpact();
    final image = _currentImage;
    final url = _resolvedUrl(image);
    if (url.isEmpty) return;

    setState(() {
      _operationLabel = 'Downloading...';
      _downloadProgress = 0;
    });
    try {
      final status = await Permission.photos.request();
      if (!status.isGranted && !status.isLimited) {
        if (!mounted) return;
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
      final bytes = await _downloadBytes(url);
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/${image.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(bytes);
      await Gal.putImage(tempFile.path);
      await tempFile.delete();
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved to gallery')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadProgress = null;
          _operationLabel = null;
        });
      }
    }
  }

  Future<void> _showShareOptions() async {
    final image = _currentImage;
    final link = 'https://same.energy/i/${image.id}';

    final option = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Share image'),
              subtitle: const Text('Download and share the image file'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Share link'),
              subtitle: const Text('Share the same.energy page link'),
              onTap: () => Navigator.pop(ctx, 'link'),
            ),
            ListTile(
              leading: const Icon(Icons.layers_outlined),
              title: const Text('Share both'),
              subtitle: const Text('Share image with the link as caption'),
              onTap: () => Navigator.pop(ctx, 'both'),
            ),
          ],
        ),
      ),
    );
    if (option == null || !mounted) return;

    switch (option) {
      case 'link':
        await share_plus.Share.share(link);
        break;
      case 'image':
      case 'both':
        setState(() {
          _operationLabel = 'Preparing...';
          _downloadProgress = 0;
        });
        try {
          final url = _resolvedUrl(image);
          final bytes = await _downloadBytes(url);
          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/${image.id}_share.jpg');
          await tempFile.writeAsBytes(bytes);
          await share_plus.Share.shareXFiles([
            share_plus.XFile(tempFile.path),
          ], text: option == 'both' ? link : null);
          await tempFile.delete();
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Share failed: $error')));
          }
        } finally {
          if (mounted) {
            setState(() {
              _downloadProgress = null;
              _operationLabel = null;
            });
          }
        }
        break;
    }
  }

  Future<void> _openSaveSheet() async {
    HapticFeedback.lightImpact();
    final result = await showCollectionPickerSheet(
      context,
      image: _currentImage,
    );
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

  Future<void> _openSearchTogether() async {
    final image = _currentImage;
    final textController = TextEditingController();
    final picker = ImagePicker();
    XFile? secondImage;
    bool uploading = false;
    double uploadProgress = 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search together',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Combine this image with text or another image',
                  style: TextStyle(
                    color: SameEnergyTheme.mutedFor(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                // Current image preview
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: _resolvedUrl(image),
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.add, size: 20),
                    const SizedBox(width: 12),
                    if (secondImage != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(secondImage!.path),
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: IconButton(
                              iconSize: 16,
                              onPressed: () =>
                                  setSheetState(() => secondImage = null),
                              icon: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _GlassChip(
                            icon: Icons.photo_library_outlined,
                            label: 'Gallery',
                            onTap: () async {
                              final f = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (f != null) {
                                setSheetState(() => secondImage = f);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          _GlassChip(
                            icon: Icons.camera_alt_outlined,
                            label: 'Camera',
                            onTap: () async {
                              final f = await picker.pickImage(
                                source: ImageSource.camera,
                              );
                              if (f != null) {
                                setSheetState(() => secondImage = f);
                              }
                            },
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    hintText: 'Add text to refine (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                if (uploading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: uploadProgress > 0 ? uploadProgress : null,
                        minHeight: 3,
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: uploading
                        ? null
                        : () async {
                            setSheetState(() {
                              uploading = true;
                              uploadProgress = 0;
                            });
                            final query = textController.text.trim();
                            String imageParam = image.id;

                            // Upload second image if provided
                            String? secondImageParam;
                            if (secondImage != null) {
                              try {
                                final hash = await uploadImageForSearch(
                                  ref,
                                  File(secondImage!.path),
                                  onProgress: (progress) {
                                    if (!ctx.mounted) return;
                                    setSheetState(() {
                                      uploadProgress = progress.clamp(0.0, 1.0);
                                    });
                                  },
                                );
                                secondImageParam = hash;
                              } catch (_) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to upload image'),
                                    ),
                                  );
                                }
                                setSheetState(() => uploading = false);
                                return;
                              }
                            }

                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);

                            final params = <String>[];
                            params.add('i=$imageParam');
                            if (secondImageParam != null) {
                              params.add('i2=$secondImageParam');
                            }
                            if (query.isNotEmpty) {
                              params.add('q=${Uri.encodeComponent(query)}');
                            }
                            params.add(
                              'rt=${DateTime.now().microsecondsSinceEpoch}',
                            );
                            if (mounted) {
                              context.go('/search?${params.join('&')}');
                            }
                          },
                    icon: uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(uploading ? 'Uploading...' : 'Search'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    textController.dispose();
  }

  void _openSource() async {
    final url = _currentImage.sourceUrl ?? _currentImage.postUrl;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _openSimilarImage(int index) {
    if (index < 0 || index >= _similarImages.length) return;
    final image = _similarImages[index];
    context.push(
      '/i/${image.id}',
      extra: ImageDetailArgs(images: _similarImages, initialIndex: index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final savedIds = ref.watch(savedItemsProvider).images.keys.toSet();
    final isSaved = savedIds.contains(_currentImage.id);
    final title = _cleanText(_currentImage.title);
    final description = _cleanText(_currentImage.description);
    final sourceLabel = _cleanSourceLabel(_currentImage);
    final settings = ref.watch(appSettingsProvider);
    final crossAxisCount = settings.gridColumns;
    final spacing = settings.imagePadding.toDouble();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openSource,
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.open_in_new,
                color: Colors.white,
                size: 18,
              ),
            ),
            tooltip: 'Open source',
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: SameEnergyGlassBackground()),
          CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Hero image
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _images.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                        _transformController.value = Matrix4.identity();
                      });
                      _loadSimilar();
                    },
                    itemBuilder: (context, index) {
                      final image = _images[index];
                      return GestureDetector(
                        onDoubleTap: _onDoubleTap,
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: CachedNetworkImage(
                            imageUrl: _resolvedUrl(image),
                            fit: BoxFit.contain,
                            placeholder: (_, __) => Container(
                              color: isDark
                                  ? const Color(0xFF121519)
                                  : const Color(0xFFF1EEE6),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: isDark
                                  ? const Color(0xFF121519)
                                  : const Color(0xFFF1EEE6),
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Image info - clean, no raw IDs
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      if (description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            description,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (sourceLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: GestureDetector(
                            onTap: _openSource,
                            child: Text(
                              sourceLabel,
                              style: TextStyle(fontSize: 12, color: accent),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // "More like this" header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'More like this',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),

              // Similar images grid - infinite scroll
              if (_similarImages.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childCount: _similarImages.length,
                    itemBuilder: (context, index) {
                      final sim = _similarImages[index];
                      return GestureDetector(
                        onTap: () => _openSimilarImage(index),
                        child: AspectRatio(
                          aspectRatio: sim.displayAspectRatio.clamp(0.5, 2.5),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: sim.displayThumbnailUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: isDark
                                    ? const Color(0xFF1A2026)
                                    : const Color(0xFFE8E4DB),
                              ),
                              errorWidget: (_, __, ___) => Container(
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
                        ),
                      );
                    },
                  ),
                ),

              // Loading indicator
              if (_loadingSimilar)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),

              // Bottom spacer
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // Bottom action bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    8,
                    12,
                    MediaQuery.of(context).padding.bottom + 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF090B0D).withValues(alpha: 0.78)
                        : const Color(0xFFF8F7F3).withValues(alpha: 0.78),
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_downloadProgress != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            children: [
                              if (_operationLabel != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    _operationLabel!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                    ),
                                  ),
                                ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: _downloadProgress! > 0
                                      ? _downloadProgress
                                      : null,
                                  minHeight: 3,
                                  backgroundColor: isDark
                                      ? Colors.white12
                                      : Colors.black12,
                                  valueColor: AlwaysStoppedAnimation(accent),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ActionButton(
                            icon: isSaved
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            label: isSaved ? 'Saved' : 'Save',
                            color: isSaved ? accent : null,
                            onTap: _openSaveSheet,
                          ),
                          _ActionButton(
                            icon: Icons.download_outlined,
                            label: 'Download',
                            onTap: _downloadCurrent,
                          ),
                          _ActionButton(
                            icon: Icons.share_outlined,
                            label: 'Share',
                            onTap: _showShareOptions,
                          ),
                          _ActionButton(
                            icon: Icons.join_full_outlined,
                            label: 'Search together',
                            onTap: _openSearchTogether,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _hasMoreData(List<SameImage> results, int requestedCount) {
  return results.length >= requestedCount;
}

List<SameImage> _mergeUniqueSimilar(
  List<SameImage> current,
  List<SameImage> incoming,
) {
  final merged = List<SameImage>.from(current);
  final ids = current.map((image) => image.id).toSet();
  for (final image in incoming) {
    if (ids.add(image.id)) {
      merged.add(image);
    }
  }
  return merged;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white70 : Colors.black54;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color ?? defaultColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color ?? defaultColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
