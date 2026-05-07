import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/game_engine.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const Color kCyan   = Color(0xFF00CFFF);
const Color kPurple = Color(0xFF9B59FF);
const Color kGold   = Color(0xFFFFD700);
const Color kRed    = Color(0xFFFF4444);
const Color kOrange = Color(0xFFFF8C00);
const Color kBg     = Color(0xFF05000F);

const List<Color> particleColors = [kCyan, kPurple, kGold, kRed, kOrange, Colors.white];

// ─── Background ───────────────────────────────────────────────────────────────
class VoidBackgroundPainter extends CustomPainter {
  final double animValue;
  final double flipProgress; // 0..1 during flip transition
  VoidBackgroundPainter(this.animValue, {this.flipProgress = 0});

  @override
  void paint(Canvas canvas, Size size) {
    // Base gradient — shifts hue during flip
    final t = flipProgress;
    final topColor    = Color.lerp(const Color(0xFF050010), const Color(0xFF100500), t)!;
    final bottomColor = Color.lerp(const Color(0xFF0A0020), const Color(0xFF200A00), t)!;

    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, bottomColor],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Starfield (static seed for consistency)
    final rng = Random(42);
    for (int i = 0; i < 90; i++) {
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextDouble() * size.height;
      final r  = rng.nextDouble() * 1.4 + 0.3;
      final twinkle = 0.35 + 0.65 * sin(animValue * 2 * pi + i * 0.71);
      canvas.drawCircle(
        Offset(sx, sy), r,
        Paint()..color = Colors.white.withOpacity(0.28 * twinkle),
      );
    }

    // Scan lines
    final linePaint = Paint()
      ..color = kCyan.withOpacity(0.03)
      ..strokeWidth = 1;
    for (int i = 0; i < size.height.toInt(); i += 22) {
      canvas.drawLine(Offset(0, i.toDouble()), Offset(size.width, i.toDouble()), linePaint);
    }

    // Flip flash overlay
    if (flipProgress > 0) {
      final flashOpacity = sin(flipProgress * pi) * 0.25;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = kPurple.withOpacity(flashOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(VoidBackgroundPainter old) =>
      old.animValue != animValue || old.flipProgress != flipProgress;
}

// ─── Game Painter ─────────────────────────────────────────────────────────────
class GamePainter extends CustomPainter {
  final GameEngine engine;
  GamePainter(this.engine);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(engine.screenShake, 0);

    _drawSurfaces(canvas, size);
    _drawObstacles(canvas, size);
    _drawPlayer(canvas, size);
    _drawParticles(canvas, size);

    canvas.restore();
  }

  // ── Surfaces (floor / ceiling lines) ─────────────────────────────────────

  void _drawSurfaces(Canvas canvas, Size size) {
    final isFloor   = engine.surface == GravSurface.floor;
    final floorY    = GameConstants.groundY  * size.height;
    final ceilingY  = GameConstants.ceilingY * size.height;

    // Floor line
    final floorPaint = Paint()
      ..color = (isFloor ? kCyan : kPurple).withOpacity(0.7)
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(0, floorY), Offset(size.width, floorY), floorPaint);

    // Floor glow
    canvas.drawRect(
      Rect.fromLTWH(0, floorY - 6, size.width, 8),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [(isFloor ? kCyan : kPurple).withOpacity(0.18), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, floorY - 6, size.width, 8)),
    );

    // Ceiling line
    final ceilPaint = Paint()
      ..color = (!isFloor ? kCyan : kPurple).withOpacity(0.7)
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(0, ceilingY), Offset(size.width, ceilingY), ceilPaint);

    // Ceiling glow
    canvas.drawRect(
      Rect.fromLTWH(0, ceilingY, size.width, 8),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, (!isFloor ? kCyan : kPurple).withOpacity(0.18)],
        ).createShader(Rect.fromLTWH(0, ceilingY, size.width, 8)),
    );
  }

  // ── Obstacles ─────────────────────────────────────────────────────────────

  void _drawObstacles(Canvas canvas, Size size) {
    final isFloor = engine.surface == GravSurface.floor;

    for (final obs in engine.obstacles) {
      final x = obs.x * size.width;
      final w = engine.obsWidth(obs.kind);  // ignore: invalid_use_of_protected_member
      _drawSingleObstacle(canvas, size, obs, x, w, isFloor);
    }
  }

  void _drawSingleObstacle(Canvas canvas, Size size, RunObstacle obs,
      double x, double w, bool isFloor) {
    if (obs.kind == ObstacleKind.voidRift) {
      _drawVoidRift(canvas, size, x, w, isFloor);
      return;
    }

    final Color color;
    switch (obs.kind) {
      case ObstacleKind.lowBlock:    color = kCyan;   break;
      case ObstacleKind.highBlock:   color = kPurple; break;
      case ObstacleKind.doubleBlock: color = kGold;   break;
      default:                       color = kCyan;
    }

    final hitboxes = engine.obsHitboxes(obs, false);  // ignore: invalid_use_of_protected_member
    for (final hb in hitboxes) {
      final top    = hb[0] * size.height;
      final bottom = hb[1] * size.height;
      final rect   = Rect.fromLTWH(x, top, w, bottom - top);

      // Glow
      canvas.drawRect(rect,
        Paint()
          ..color = color.withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10),
      );

      // Fill
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [color.withOpacity(0.95), color.withOpacity(0.55)],
          ).createShader(rect),
      );

      // Edge shine
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = Colors.white.withOpacity(0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawVoidRift(Canvas canvas, Size size, double x, double w, bool isFloor) {
    final centerY = isFloor
        ? GameConstants.groundY * size.height - 40
        : GameConstants.ceilingY * size.height + 40;
    final h = 60.0;
    final rect = Rect.fromLTWH(x, centerY - h / 2, w, h);

    // Pulsing gold rift
    canvas.drawOval(rect,
      Paint()
        ..color = kGold.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 16),
    );
    canvas.drawOval(rect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, kGold],
        ).createShader(rect),
    );
  }

  // ── Player (humanoid silhouette) ──────────────────────────────────────────

  void _drawPlayer(Canvas canvas, Size size) {
    final px        = size.width * 0.12;
    final py        = engine.playerY * size.height;
    final isFloor   = engine.surface == GravSurface.floor;
    final isSliding = engine.playerAction == PlayerAction.slide;
    final isJumping = engine.playerAction == PlayerAction.jump;
    final isDead    = engine.playerAction == PlayerAction.dead;

    if (isDead) return;

    // Flip the canvas coordinate system for ceiling running
    canvas.save();

    // Anchor Y to surface
    final anchorY = isFloor ? py : py;

    if (!isFloor) {
      // Mirror vertically around player center
      canvas.translate(px, anchorY);
      canvas.scale(1, -1);
      canvas.translate(-px, -anchorY);
    }

    final color    = isFloor ? kCyan : kPurple;
    final glowOpac = isJumping ? 0.4 : 0.2;

    // Body glow
    canvas.drawRect(
      Rect.fromLTWH(px - 16, anchorY - 48, 32, 48),
      Paint()
        ..color = color.withOpacity(glowOpac)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 12),
    );

    if (isSliding) {
      // Slide pose — flat rectangle hugging surface
      _drawSlide(canvas, px, anchorY, color);
    } else if (isJumping) {
      _drawJump(canvas, px, anchorY, color);
    } else {
      _drawRun(canvas, px, anchorY, color, size);
    }

    canvas.restore();
  }

  void _drawRun(Canvas canvas, double px, double py, Color color, Size size) {
    final t = DateTime.now().millisecondsSinceEpoch / 150.0; // leg animation
    final legSwing = sin(t) * 8;

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(0.95), color],
      ).createShader(Rect.fromLTWH(px - 8, py - 44, 16, 44));

    // Torso
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(px - 8, py - 38, 16, 22), const Radius.circular(4)),
      bodyPaint,
    );

    // Head
    canvas.drawCircle(
      Offset(px, py - 44),
      8,
      Paint()..color = Colors.white.withOpacity(0.9),
    );

    // Left leg
    _drawLeg(canvas, px - 5, py - 16, legSwing, color);
    // Right leg
    _drawLeg(canvas, px + 5, py - 16, -legSwing, color);

    // Left arm swing
    _drawArm(canvas, px - 8, py - 34, -legSwing * 0.6, color);
    // Right arm swing
    _drawArm(canvas, px + 8, py - 34, legSwing * 0.6, color);
  }

  void _drawJump(Canvas canvas, double px, double py, Color color) {
    // Tucked jump pose
    final bodyPaint = Paint()..color = Colors.white.withOpacity(0.9);

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(px - 8, py - 38, 16, 22), const Radius.circular(4)),
      Paint()..color = color.withOpacity(0.9),
    );

    // Head
    canvas.drawCircle(Offset(px, py - 44), 8, bodyPaint);

    // Tucked legs
    final legPaint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(px - 5, py - 16), Offset(px - 10, py - 8), legPaint);
    canvas.drawLine(Offset(px + 5, py - 16), Offset(px + 10, py - 8), legPaint);
  }

  void _drawSlide(Canvas canvas, double px, double py, Color color) {
    // Flat horizontal slide
    final rect = Rect.fromLTWH(px - 18, py - 18, 36, 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withOpacity(0.9), color],
        ).createShader(rect),
    );
    // Head
    canvas.drawCircle(
      Offset(px + 14, py - 12), 7,
      Paint()..color = Colors.white.withOpacity(0.9),
    );
  }

  void _drawLeg(Canvas canvas, double x, double y, double swing, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(0.9)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, y), Offset(x + swing * 0.4, y + 12), paint);
    canvas.drawLine(Offset(x + swing * 0.4, y + 12), Offset(x + swing * 0.6, y + 22), paint);
  }

  void _drawArm(Canvas canvas, double x, double y, double swing, Color color) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, y), Offset(x + swing, y + 12), paint);
  }

  // ── Particles ─────────────────────────────────────────────────────────────

  void _drawParticles(Canvas canvas, Size size) {
    for (final p in engine.particles) {
      final color = particleColors[p.colorIndex % particleColors.length];
      canvas.drawCircle(
        Offset(p.x, p.y), 4 * p.scale,
        Paint()
          ..color = color.withOpacity(p.opacity.clamp(0, 1))
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5),
      );
    }
  }

  @override
  bool shouldRepaint(GamePainter old) => true;
}

// ─── HUD Painter ──────────────────────────────────────────────────────────────
class HudPainter extends CustomPainter {
  final GameEngine engine;
  HudPainter(this.engine);

  @override
  void paint(Canvas canvas, Size size) {
    // Void energy bar
    const barH = 5.0;
    final barW = size.width * 0.52;
    final barX = (size.width - barW) / 2;
    const barY = 28.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW, barH), const Radius.circular(3)),
      Paint()..color = Colors.white.withOpacity(0.1),
    );

    if (engine.voidEnergy > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barW * engine.voidEnergy, barH),
          const Radius.circular(3),
        ),
        Paint()
          ..shader = const LinearGradient(
            colors: [kCyan, kGold],
          ).createShader(Rect.fromLTWH(barX, barY, barW, barH)),
      );
    }

    // Void mode flash
    if (engine.isVoidMode) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = kGold.withOpacity(0.05),
      );
    }

    // Surface indicator (top-left icon)
    final surfText = engine.surface == GravSurface.floor ? '▼ FLOOR' : '▲ CEILING';
    final surfColor = engine.surface == GravSurface.floor ? kCyan : kPurple;
    final tp = TextPainter(
      text: TextSpan(
        text: surfText,
        style: TextStyle(
          color: surfColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(16, 20));

    // Multiplier
    if (engine.multiplier > 1) {
      final mp = TextPainter(
        text: TextSpan(
          text: 'x${engine.multiplier}',
          style: const TextStyle(
            color: kGold, fontSize: 13, fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      mp.paint(canvas, Offset(size.width - 44, 20));
    }
  }

  @override
  bool shouldRepaint(HudPainter old) => true;
}
