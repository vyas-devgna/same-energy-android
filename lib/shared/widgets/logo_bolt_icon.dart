import 'package:flutter/material.dart';

class SameEnergyBoltIcon extends StatelessWidget {
  const SameEnergyBoltIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFF0F0F0)
            : const Color(0xFF1A1A1A));

    return SizedBox(
      width: size,
      height: size * 1.35,
      child: CustomPaint(painter: _BoltPainter(resolvedColor)),
    );
  }
}

class _BoltPainter extends CustomPainter {
  _BoltPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final top = Path()
      ..moveTo(size.width * 0.10, size.height * 0.45)
      ..lineTo(size.width * 0.58, size.height * 0.05)
      ..lineTo(size.width * 0.43, size.height * 0.42)
      ..lineTo(size.width * 0.90, size.height * 0.42)
      ..lineTo(size.width * 0.35, size.height * 0.88)
      ..lineTo(size.width * 0.54, size.height * 0.50)
      ..lineTo(size.width * 0.10, size.height * 0.50)
      ..close();

    final overlay = Path()
      ..moveTo(size.width * 0.20, size.height * 0.48)
      ..lineTo(size.width * 0.40, size.height * 0.30)
      ..lineTo(size.width * 0.33, size.height * 0.46)
      ..lineTo(size.width * 0.63, size.height * 0.46)
      ..lineTo(size.width * 0.26, size.height * 0.76)
      ..lineTo(size.width * 0.37, size.height * 0.55)
      ..lineTo(size.width * 0.20, size.height * 0.55)
      ..close();

    canvas.drawPath(top, paint);
    canvas.drawPath(
      overlay,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _BoltPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
