import 'package:flutter/material.dart';
import 'dart:math' as math;

class SiriLogoPainter extends CustomPainter {
  final double animationValue;
  final double innerDiameter;
  final double outerDiameter;
  final double soundLevel;

  SiriLogoPainter({
    required this.animationValue,
    required this.innerDiameter,
    required this.outerDiameter,
    this.soundLevel = 0.5, // Default sound level
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minRadius = innerDiameter / 2;
    final maxRadius = outerDiameter / 2;

    // Menghitung radius berdasarkan animasi dan level suara
    // Gunakan soundLevel untuk memperbesar radius saat suara lebih keras
    final baseRadius = minRadius + (maxRadius - minRadius) * animationValue;

    // Efek suara yang lebih dinamis - hingga 40% dari rentang radius
    final soundEffect = (maxRadius - minRadius) * 0.1 * soundLevel;
    final currentRadius = baseRadius + soundEffect;

    // Tambahkan variasi warna berdasarkan level suara
    final List<Color> colors = [
      Colors.purpleAccent,
      soundLevel > 0.7 ? Colors.pinkAccent : Colors.blueAccent,
      soundLevel > 0.8 ? Colors.redAccent : Colors.cyanAccent,
      soundLevel > 0.9 ? Colors.orangeAccent : Colors.greenAccent,
      Colors.purpleAccent,
    ];

    // Kecepatan rotasi meningkat dengan level suara
    final rotationSpeed = 2.0 + (soundLevel * 2.0);

    final gradient = SweepGradient(
      colors: colors,
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      transform: GradientRotation(animationValue * 3.1416 * rotationSpeed),
    ).createShader(Rect.fromCircle(center: center, radius: currentRadius));

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, currentRadius, paint);
  }

  @override
  bool shouldRepaint(covariant SiriLogoPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.innerDiameter != innerDiameter ||
      oldDelegate.outerDiameter != outerDiameter ||
      oldDelegate.soundLevel != soundLevel;
}
