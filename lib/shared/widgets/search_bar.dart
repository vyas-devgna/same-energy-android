import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum SearchImageMode { together, manual }

class PickedSearchImage {
  final XFile file;
  final String query;
  final SearchImageMode mode;

  PickedSearchImage({
    required this.file,
    required this.query,
    required this.mode,
  });
}

class AppSearchBar extends StatefulWidget {
  final void Function(String query)? onSearch;
  final void Function(PickedSearchImage picked)? onImagePicked;
  final String? initialQuery;
  final bool showUploadProgress;
  final double uploadProgress;
  final Future<SearchImageMode> Function(bool hasExistingImage)?
  onModeRequested;
  final bool hasActiveImage;

  const AppSearchBar({
    super.key,
    this.onSearch,
    this.onImagePicked,
    this.initialQuery,
    this.showUploadProgress = false,
    this.uploadProgress = 0,
    this.onModeRequested,
    this.hasActiveImage = false,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextQuery = widget.initialQuery ?? '';
    if (!FocusScope.of(context).hasFocus && nextQuery != _controller.text) {
      _controller.value = TextEditingValue(
        text: nextQuery,
        selection: TextSelection.collapsed(offset: nextQuery.length),
      );
    }
  }

  void _submitSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      final query = _controller.text.trim();
      if (query.isEmpty) return;
      widget.onSearch?.call(query);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(source: source, imageQuality: 85);
    if (xFile == null || !mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _selectedImage = File(xFile.path));

    final currentQuery = _controller.text.trim();
    SearchImageMode? mode;
    if (!widget.hasActiveImage && currentQuery.isEmpty) {
      // Empty text should directly perform image-only search.
      mode = SearchImageMode.manual;
    } else {
      final requestedMode = widget.onModeRequested;
      mode = requestedMode == null
          ? await _selectSearchMode(allowSecondary: widget.hasActiveImage)
          : await requestedMode(widget.hasActiveImage);
    }
    if (mode == null) {
      setState(() => _selectedImage = null);
      return;
    }
    widget.onImagePicked?.call(
      PickedSearchImage(
        file: xFile,
        query: currentQuery,
        mode: mode,
      ),
    );
    if (mounted) {
      setState(() => _selectedImage = null);
    }
  }

  Future<SearchImageMode?> _selectSearchMode({required bool allowSecondary}) async {
    return showModalBottomSheet<SearchImageMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!allowSecondary) ...[
              ListTile(
                leading: const Icon(Icons.image_search_outlined),
                title: const Text('Search by image only'),
                subtitle: const Text('Upload an image and search visually'),
                onTap: () => Navigator.pop(ctx, SearchImageMode.manual),
              ),
              ListTile(
                leading: const Icon(Icons.join_full_outlined),
                title: const Text('Search with text'),
                subtitle: const Text('Combine image with your text query'),
                onTap: () => Navigator.pop(ctx, SearchImageMode.together),
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.join_full_outlined),
                title: const Text('Search together'),
                subtitle: const Text('Use both images and optional text'),
                onTap: () => Navigator.pop(ctx, SearchImageMode.together),
              ),
              ListTile(
                leading: const Icon(Icons.image_search_outlined),
                title: const Text('Search manually'),
                subtitle: const Text('Replace the current image search seed'),
                onTap: () => Navigator.pop(ctx, SearchImageMode.manual),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showImageSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A2026).withValues(alpha: 0.8)
                  : const Color(0xFFF1EEE6).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.search,
                  size: 20,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => _submitSearch(),
                    onSubmitted: (_) => _submitSearch(),
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search for images...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: _showImageSourcePicker,
                  icon: Icon(
                    Icons.camera_alt_outlined,
                    size: 20,
                    color: accent.withValues(alpha: 0.8),
                  ),
                  tooltip: 'Search by image',
                ),
              ],
            ),
          ),
        ),
        if (widget.showUploadProgress)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: widget.uploadProgress > 0 ? widget.uploadProgress : null,
                minHeight: 3,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ),
      ],
    );
  }
}
