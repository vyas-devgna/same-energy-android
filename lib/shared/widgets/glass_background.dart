import 'package:flutter/material.dart';

class SameEnergyGlassBackground extends StatelessWidget {
  const SameEnergyGlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topColor = isDark ? const Color(0xFF0F141B) : const Color(0xFFF5F3EE);
    final bottomColor = isDark
        ? const Color(0xFF080A0C)
        : const Color(0xFFEFE9DD);
    final orbA = Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.12);
    final orbB = isDark
        ? const Color(0xFF4A90D9).withValues(alpha: 0.08)
        : const Color(0xFFE6B56A).withValues(alpha: 0.10);

    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [topColor, bottomColor],
              ),
            ),
          ),
          Positioned(
            left: -60,
            top: -40,
            child: _GlowOrb(color: orbA, size: 220),
          ),
          Positioned(
            right: -80,
            top: 180,
            child: _GlowOrb(color: orbB, size: 260),
          ),
          Positioned(
            left: 80,
            bottom: -120,
            child: _GlowOrb(color: orbA.withValues(alpha: 0.06), size: 280),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: size * 0.22,
            spreadRadius: size * 0.03,
          ),
        ],
      ),
    );
  }
}

