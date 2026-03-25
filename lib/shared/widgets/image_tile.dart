import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/models/image_model.dart';

class ImageTile extends StatefulWidget {
  const ImageTile({
    super.key,
    required this.image,
    required this.heroTag,
    this.isBookmarked = false,
    this.isSelected = false,
    this.selectionMode = false,
    this.onTap,
    this.onLongPress,
    this.onQuickSave,
    this.onDoubleTap,
  });

  final SameImage image;
  final String heroTag;
  final bool isBookmarked;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onQuickSave;
  final VoidCallback? onDoubleTap;

  @override
  State<ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<ImageTile>
    with SingleTickerProviderStateMixin {
  bool _showActions = false;
  bool _showDoubleTapHeart = false;
  double _tapScale = 1.0;

  void _handleTap() {
    widget.onTap?.call();
    _animateTap();
  }

  void _handleDoubleTap() {
    HapticFeedback.lightImpact();
    if (widget.onDoubleTap != null) {
      widget.onDoubleTap!();
    } else if (widget.onQuickSave != null && !widget.isBookmarked) {
      widget.onQuickSave!();
    }
    setState(() => _showDoubleTapHeart = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showDoubleTapHeart = false);
    });
  }

  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    if (widget.onLongPress != null) {
      widget.onLongPress!();
    } else if (!widget.selectionMode) {
      setState(() => _showActions = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showActions = false);
      });
    }
  }

  void _animateTap() {
    setState(() => _tapScale = 0.97);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _tapScale = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final aspectRatio = widget.image.displayAspectRatio.clamp(0.4, 3.0);

    // Calculate a reasonable memCacheWidth to reduce memory usage
    final screenWidth = MediaQuery.of(context).size.width;
    final memCacheWidth = (screenWidth / 2).round().clamp(150, 400);

    return AnimatedScale(
      scale: _tapScale,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTap: _handleTap,
        onDoubleTap: _handleDoubleTap,
        onLongPress: _handleLongPress,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: widget.isSelected
                  ? Border.all(color: accent, width: 2.5)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.isSelected ? 10 : 12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.image.displayThumbnailUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 90),
                    memCacheWidth: memCacheWidth,
                    placeholder: (context, url) => Container(
                      color: isDark
                          ? const Color(0xFF1A2026)
                          : const Color(0xFFE8E4DB),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark
                          ? const Color(0xFF1A2026)
                          : const Color(0xFFE8E4DB),
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                  ),
                  // Selection overlay with animated opacity
                  if (widget.selectionMode)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isSelected
                              ? accent
                              : Colors.black.withValues(alpha: 0.45),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: widget.isSelected
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  // Bookmark indicator
                  if (widget.isBookmarked && !widget.selectionMode)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.bookmark,
                        size: 18,
                        color: accent,
                        shadows: const [
                          Shadow(blurRadius: 6, color: Colors.black54),
                        ],
                      ),
                    ),
                  // Quick actions with animated opacity
                  AnimatedOpacity(
                    opacity:
                        (_showActions && !widget.selectionMode) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: (_showActions && !widget.selectionMode)
                        ? Positioned(
                            bottom: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onQuickSave?.call();
                                setState(() => _showActions = false);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  widget.isBookmarked
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  // Double-tap heart animation
                  if (_showDoubleTapHeart)
                    Center(
                      child: AnimatedOpacity(
                        opacity: _showDoubleTapHeart ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: AnimatedScale(
                          scale: _showDoubleTapHeart ? 1.0 : 0.5,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.elasticOut,
                          child: Icon(
                            Icons.favorite,
                            size: 64,
                            color: accent.withValues(alpha: 0.85),
                            shadows: const [
                              Shadow(blurRadius: 16, color: Colors.black45),
                            ],
                          ),
                        ),
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
