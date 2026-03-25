import 'package:flutter/material.dart';

class FeedChipRow extends StatelessWidget {
  final List<String> feeds;
  final String? selectedFeed;
  final void Function(String feed)? onFeedSelected;

  const FeedChipRow({
    super.key,
    required this.feeds,
    this.selectedFeed,
    this.onFeedSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: feeds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final feed = feeds[index];
          final selected = feed == selectedFeed;
          return _FeedChip(
            label: feed,
            selected: selected,
            onTap: () => onFeedSelected?.call(feed),
          );
        },
      ),
    );
  }
}

class _FeedChip extends StatefulWidget {
  const _FeedChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FeedChip> createState() => _FeedChipState();
}

class _FeedChipState extends State<_FeedChip> {
  double _scale = 1;

  void _animateTap() {
    setState(() => _scale = 0.93);
    Future<void>.delayed(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      setState(() => _scale = 1);
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _animateTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected
                ? accent.withValues(alpha: isDark ? 0.22 : 0.12)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.5)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.10)),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? accent
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}
