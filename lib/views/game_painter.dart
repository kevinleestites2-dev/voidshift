import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/game_engine.dart';

// ─── Color palette ────────────────────────────────────────────────────────────
const List<Color> particleColors = [
  Color(0xFF00CFFF), // 0 cyan
  Color(0xFF9B59FF), // 1 purple
  Color(0xFFFFD700), // 2 yellow
  Color(0xFFFF4444), // 3 red
  Color(0xFFFF8C00), // 4 orange
  Color(0xFFFFD700), // 5 gold
];

// ─── Background Painter ───────────────────────────────────────────────────────
class VoidBackgroundPainter extends CustomPainter {
  final double animValue;
  VoidBackgroundPainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    // Deep space gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF050010), Color(0xFF0A0020), Color(0xFF050015)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Starfield
    final starPaint = Paint()..color = Colors.white.withOpacity(0.6);
    final rng = Random(42);
    for (int i = 0; i < 80; i++) {
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.5 + 0.3;
      final twinkle = 0.4 + 0.6 * sin(animValue * 2 * pi + i * 0.7);
      starPaint.color = Colors.white.withOpacity(0.3 * twinkle);
      canvas.drawCircle(Offset(sx, sy), r, starPaint);
    }

    // Void glow lines (horizontal scanlines)
    final linePaint = Paint()
      ..color = const Color(0xFF00CFFF).withOpacity(0.04)
      ..strokeWidth = 1;
    for (int i = 0; i < size.height.toInt(); i += 24) {
      canvas.drawLine(Offset(0, i.toDouble()), Offset(size.width, i.toDouble()), linePaint);
    }
  }

  @override
  bool shouldRepaint(VoidBackgroundPainter old) => old.animValue != animValue;
}

// ─── Game Painter ─────────────────────────────────────────────────────────────
class GamePainter extends CustomPainter {
  final GameEngine engine;
  GamePainter(this.engine);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(engine.screenShake, 0);

    _drawObstacles(canvas, size);
    _drawPlayer(canvas, size);
    _drawParticles(canvas, size);
    _drawHUD(canvas, size);

    canvas.restore();
  }

  void _drawObstacles(Canvas canvas, Size size) {
    for (final obs in engine.obstacles) {
      final x = obs.x * size.width;
      final w = GameConstants.obstacleWidth;
      final gapTop = (obs.gapY - obs.gapSize / 2) * size.height;
      final gapBottom = (obs.gapY + obs.gapSize / 2) * size.height;

      final color = obs.isVoidRift
          ? const Color(0xFFFFD700)
          : const Color(0xFF9B59FF);
      final glowColor = obs.isVoidRift
          ? const Color(0xFFFFD700).withOpacity(0.3)
          : const Color(0xFF6B2FBF).withOpacity(0.4);

      // Glow
      final glowPaint = Paint()
        ..color = glowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 12);

      // Top pillar
      final topRect = Rect.fromLTWH(x, 0, w, gapTop);
      final botRect = Rect.fromLTWH(x, gapBottom, w, size.height - gapBottom);

      canvas.drawRect(topRect, glowPaint);
      canvas.drawRect(botRect, glowPaint);

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [color.withOpacity(0.9), color.withOpacity(0.6)],
        ).createShader(topRect);
      canvas.drawRect(topRect, fillPaint);

      final fillPaint2 = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [color.withOpacity(0.9), color.withOpacity(0.6)],
        ).createShader(botRect);
      canvas.drawRect(botRect, fillPaint2);

      // Gap edge glow
      final edgePaint = Paint()
        ..color = color.withOpacity(0.8)
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, gapTop), Offset(x + w, gapTop), edgePaint);
      canvas.drawLine(Offset(x, gapBottom), Offset(x + w, gapBottom), edgePaint);
    }
  }

  void _drawPlayer(Canvas canvas, Size size) {
    final px = size.width * 0.15;
    final py = engine.playerY * size.height;
    final r = GameConstants.playerSize / 2;

    final isUp = engine.gravityDirection == GravityDirection.up;
    final coreColor = isUp ? const Color(0xFF9B59FF) : const Color(0xFF00CFFF);

    // Outer glow
    canvas.drawCircle(
      Offset(px, py), r + 10,
      Paint()
        ..color = coreColor.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 14),
    );

    // Core
    canvas.drawCircle(
      Offset(px, py), r,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withOpacity(0.9), coreColor],
        ).createShader(Rect.fromCircle(center: Offset(px, py), radius: r)),
    );

    // Direction arrow
    final arrowPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final arrowDir = isUp ? -1.0 : 1.0;
    canvas.drawLine(
      Offset(px - 6, py + arrowDir * 4),
      Offset(px, py - arrowDir * 5),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(px + 6, py + arrowDir * 4),
      Offset(px, py - arrowDir * 5),
      arrowPaint,
    );
  }

  void _drawParticles(Canvas canvas, Size size) {
    for (final p in engine.particles) {
      final color = particleColors[p.colorIndex % particleColors.length];
      canvas.drawCircle(
        Offset(p.x, p.y),
        4 * p.scale,
        Paint()
          ..color = color.withOpacity(p.opacity.clamp(0, 1))
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4),
      );
    }
  }

  void _drawHUD(Canvas canvas, Size size) {
    // Void energy bar
    final barW = size.width * 0.5;
    final barH = 4.0;
    final barX = (size.width - barW) / 2;
    const barY = 28.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW, barH), const Radius.circular(2)),
      Paint()..color = Colors.white.withOpacity(0.12),
    );
    if (engine.voidEnergy > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barW * engine.voidEnergy, barH),
          const Radius.circular(2),
        ),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF00CFFF), Color(0xFFFFD700)],
          ).createShader(Rect.fromLTWH(barX, barY, barW, barH)),
      );
    }

    // Void mode flash
    if (engine.isVoidMode) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFFFD700).withOpacity(0.06),
      );
    }
  }

  @override
  bool shouldRepaint(GamePainter old) => true;
}
