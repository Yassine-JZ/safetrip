import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Épingle de localisation bleue contenant une voiture, avec une route verte.
class SafeTripLogo extends StatelessWidget {
  const SafeTripLogo({super.key, this.size = 56, this.inverted = false});

  final double size;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PinPainter(inverted: inverted),
        child: Align(
          alignment: const Alignment(0, -0.32),
          child: Icon(
            Icons.directions_car_filled_rounded,
            size: size * 0.38,
            color: inverted ? AppColors.primary : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  const _PinPainter({required this.inverted});

  final bool inverted;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.46;
    final r = w * 0.36;
    final cy = h * 0.38;

    final pin = Path.combine(
      PathOperation.union,
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      Path()
        ..moveTo(cx - r * 0.78, cy + r * 0.62)
        ..quadraticBezierTo(cx - r * 0.2, cy + r * 1.35, cx, h * 0.97)
        ..quadraticBezierTo(
          cx + r * 0.2,
          cy + r * 1.35,
          cx + r * 0.78,
          cy + r * 0.62,
        )
        ..close(),
    );

    canvas.drawShadow(
      pin,
      Colors.black.withValues(alpha: 0.35),
      w * 0.04,
      false,
    );
    canvas.drawPath(
      pin,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: inverted
              ? [Colors.white, const Color(0xFFE3ECFF)]
              : [const Color(0xFF2F6BFF), AppColors.primaryDark],
        ).createShader(Offset.zero & size),
    );

    final road = Path()
      ..moveTo(w * 0.18, h * 0.98)
      ..cubicTo(w * 0.55, h * 0.78, w * 0.98, h * 0.62, w * 0.86, h * 0.12);
    canvas.drawPath(
      road,
      Paint()
        ..color = AppColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.09
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      road,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.018
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PinPainter oldDelegate) =>
      oldDelegate.inverted != inverted;
}

class SafeTripWordmark extends StatelessWidget {
  const SafeTripWordmark({super.key, this.fontSize = 44});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Safe',
            style: style.copyWith(color: AppColors.primaryDark),
          ),
          TextSpan(
            text: 'Trip',
            style: style.copyWith(color: AppColors.green),
          ),
        ],
      ),
    );
  }
}
