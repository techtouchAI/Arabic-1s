import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Calligraphic nib + Mesopotamian arch emblem for بَيَان.
class BayanEmblem extends StatelessWidget {
  const BayanEmblem({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[AppColors.terracotta, AppColors.deepTeal],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: CustomPaint(
        painter: _NibPainter(),
      ),
    );
  }
}

class _NibPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final nibPaint = Paint()
      ..color = AppColors.paper
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(cx, size.height * 0.16)
      ..lineTo(size.width * 0.72, cy * 1.05)
      ..lineTo(cx, size.height * 0.74)
      ..lineTo(size.width * 0.28, cy * 1.05)
      ..close();
    canvas.drawPath(path, nibPaint);

    final slitPaint = Paint()
      ..color = AppColors.deepTeal
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, size.height * 0.26),
      Offset(cx, cy * 1.02),
      slitPaint,
    );

    final dotPaint = Paint()..color = const Color(0xFFE7BA64);
    canvas.drawCircle(
      Offset(cx, size.height * 0.84),
      size.width * 0.065,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
