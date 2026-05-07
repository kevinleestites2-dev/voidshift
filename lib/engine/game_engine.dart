import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
class GameConstants {
  static const double playerW       = 32;
  static const double playerH       = 48;
  static const double groundY       = 0.88;   // floor line (normalised)
  static const double ceilingY      = 0.12;   // ceiling line (normalised)
  static const double baseSpeed     = 260;    // px/s
  static const double speedStep     = 10;
  static const int    speedEvery    = 6;      // score points between speed ups
  static const double gravity       = 1800;   // px/s²
  static const double jumpImpulse   = -780;   // negative = up
  static const double slideHeight   = 22;     // squished player height while sliding
  // Flip interval — world flips every N score points
  static const int    flipInterval  = 12;
}

// ─── Enums ───────────────────────────────────────────────────────────────────
enum GameState   { menu, playing, paused, gameOver }
enum GravSurface { floor, ceiling }           // which surface player sticks to
enum PlayerAction { run, jump, slide, dead }

// ─── Models ──────────────────────────────────────────────────────────────────

class RunObstacle {
  final String id;
  double x;
  final ObstacleKind kind;

  RunObstacle({required this.x, required this.kind}) : id = 'o${_c++}';
  static int _c = 0;
}

enum ObstacleKind {
  lowBlock,    // crouch / slide under
  highBlock,   // jump over
  doubleBlock, // two blocks — must slide under gap OR jump over lower
  voidRift,    // power-up — pass through for void energy
}

class Particle {
  double x, y, vx, vy, opacity, scale, age, lifetime;
  int colorIndex;
  Particle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.opacity, required this.scale,
    required this.colorIndex, required this.lifetime,
    this.age = 0,
  });
}

class LoreEntry {
  final int threshold;
  final String text;
  LoreEntry(this.threshold, this.text);
}

final List<LoreEntry> voidLore = [
  LoreEntry(5,  "you entered the void.\nit noticed."),
  LoreEntry(12, "the ceiling is just another floor\nif you're brave enough."),
  LoreEntry(25, "others ran here.\nthey forgot which way was down."),
  LoreEntry(40, "the void is inverting you.\nyou're starting to like it."),
  LoreEntry(60, "you have no floor.\nyou have no ceiling.\nyou just have speed."),
  LoreEntry(90, "the void counted your flips.\nit found that... interesting."),
  LoreEntry(120,"you are not running through the void.\nthe void is running through you."),
];

// ─── Game Engine ─────────────────────────────────────────────────────────────
class GameEngine extends ChangeNotifier {
  // ── Public state ──────────────────────────────────────────────────────────
  GameState    gameState   = GameState.menu;
  GravSurface  surface     = GravSurface.floor;
  PlayerAction playerAction= PlayerAction.run;

  int    score             = 0;
  int    highScore         = 0;
  int    totalCoins        = 0;
  int    coinsEarnedThisRun= 0;
  int    combo             = 0;
  int    multiplier        = 1;
  double voidEnergy        = 0;
  bool   isVoidMode        = false;
  double screenShake       = 0;

  // Player position (normalised 0..1 vertically)
  double playerY           = GameConstants.groundY;
  double playerVY          = 0;   // px/s

  // World-flip transition
  bool   isFlipping        = false;
  double flipProgress      = 0;   // 0..1 during transition animation
  int    _lastFlipScore    = 0;

  // Obstacles
  List<RunObstacle> obstacles = [];

  // Particles
  List<Particle> particles = [];

  // Lore
  String? activeLoreMessage;
  bool    showLoreMessage  = false;

  // Score popup
  bool showScorePopup      = false;
  int  scorePopupValue     = 0;

  // Screen dims (set by widget)
  double screenWidth  = 390;
  double screenHeight = 844;

  // ── Private ───────────────────────────────────────────────────────────────
  Timer?   _loopTimer;
  DateTime _lastTime          = DateTime.now();
  double   _obstacleTimer     = 0;
  double   _obstacleInterval  = 1.6;
  double   _currentSpeed      = GameConstants.baseSpeed;
  double   _shakeTimer        = 0;
  double   _loreTimer         = 0;
  double   _flipAnimTimer     = 0;
  bool     _isOnGround        = true;   // true if touching surface
  Set<int> _triggeredLore     = {};
  final    Random _rng        = Random();

  // ── Control ───────────────────────────────────────────────────────────────

  void startGame() {
    score             = 0;
    combo             = 0;
    multiplier        = 1;
    voidEnergy        = 0;
    isVoidMode        = false;
    isFlipping        = false;
    flipProgress      = 0;
    _lastFlipScore    = 0;
    surface           = GravSurface.floor;
    playerY           = GameConstants.groundY;
    playerVY          = 0;
    playerAction      = PlayerAction.run;
    _isOnGround       = true;
    obstacles         = [];
    particles         = [];
    coinsEarnedThisRun= 0;
    _currentSpeed     = GameConstants.baseSpeed;
    _obstacleTimer    = 0;
    _obstacleInterval = 1.6;
    _shakeTimer       = 0;
    _loreTimer        = 0;
    _flipAnimTimer    = 0;
    _triggeredLore    = {};
    activeLoreMessage = null;
    showLoreMessage   = false;
    screenShake       = 0;
    gameState         = GameState.playing;
    _startLoop();
    notifyListeners();
  }

  void pauseGame() {
    gameState = GameState.paused;
    _stopLoop();
    notifyListeners();
  }

  void resumeGame() {
    gameState = GameState.playing;
    _lastTime = DateTime.now();
    _startLoop();
    notifyListeners();
  }

  void endGame() {
    _stopLoop();
    if (score > highScore) highScore = score;
    final earned = max(1, score ~/ 5);
    totalCoins += earned;
    coinsEarnedThisRun = earned;
    playerAction = PlayerAction.dead;
    _spawnDeathParticles();
    gameState = GameState.gameOver;
    notifyListeners();
  }

  // ── Input ─────────────────────────────────────────────────────────────────
  // Called on tap — context-sensitive:
  //   floor surface: tap = jump
  //   ceiling surface: tap = "jump" off ceiling (push downward)

  void handleTap() {
    if (gameState != GameState.playing) return;
    if (isFlipping) return; // no input during world flip
    if (playerAction == PlayerAction.slide) {
      // cancel slide early
      playerAction = PlayerAction.run;
      return;
    }
    if (_isOnGround) {
      _doJump();
    }
  }

  // Called on swipe down — context-sensitive:
  //   floor: slide
  //   ceiling: same as jump (push off ceiling downward)

  void handleSwipeDown() {
    if (gameState != GameState.playing) return;
    if (isFlipping) return;
    if (surface == GravSurface.floor) {
      if (_isOnGround) _doSlide();
    } else {
      // on ceiling — swipe down = push off (same as jump on ceiling)
      if (_isOnGround) _doJump();
    }
  }

  // Called on swipe up — context-sensitive:
  //   floor: same as tap (jump)
  //   ceiling: slide along ceiling

  void handleSwipeUp() {
    if (gameState != GameState.playing) return;
    if (isFlipping) return;
    if (surface == GravSurface.ceiling) {
      if (_isOnGround) _doSlide();
    } else {
      if (_isOnGround) _doJump();
    }
  }

  void activateVoidMode() {
    if (voidEnergy < 1.0 || gameState != GameState.playing) return;
    isVoidMode    = true;
    voidEnergy    = 0;
    notifyListeners();
  }

  // ── Jump / Slide helpers ───────────────────────────────────────────────────

  void _doJump() {
    // Floor: negative VY = upward.  Ceiling: positive VY = downward.
    playerVY = surface == GravSurface.floor
        ? GameConstants.jumpImpulse
        : -GameConstants.jumpImpulse;
    _isOnGround   = false;
    playerAction  = PlayerAction.jump;
    _spawnJumpParticles();
    notifyListeners();
  }

  void _doSlide() {
    playerAction = PlayerAction.slide;
    // Auto cancel slide after 0.45s
    Future.delayed(const Duration(milliseconds: 450), () {
      if (playerAction == PlayerAction.slide) {
        playerAction = PlayerAction.run;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  // ── Loop ──────────────────────────────────────────────────────────────────

  void _startLoop() {
    _lastTime = DateTime.now();
    _loopTimer = Timer.periodic(
      const Duration(microseconds: 16667), (_) => _update());
  }

  void _stopLoop() {
    _loopTimer?.cancel();
    _loopTimer = null;
  }

  void _update() {
    final now = DateTime.now();
    final dt  = min(now.difference(_lastTime).inMicroseconds / 1e6, 0.05);
    _lastTime = now;
    if (gameState != GameState.playing) return;

    _updateFlipAnim(dt);
    _updatePhysics(dt);
    _updateObstacles(dt);
    _updateParticles(dt);
    _updateTimers(dt);
    _checkCollisions();
    _checkWorldFlip();
    _updateLore(dt);
    notifyListeners();
  }

  // ── World Flip ────────────────────────────────────────────────────────────

  void _checkWorldFlip() {
    if (isFlipping) return;
    final nextFlip = _lastFlipScore + GameConstants.flipInterval;
    if (score >= nextFlip) {
      _triggerWorldFlip();
    }
  }

  void _triggerWorldFlip() {
    isFlipping     = true;
    flipProgress   = 0;
    _flipAnimTimer = 0;
    _lastFlipScore = score;
    _spawnFlipParticles();
    _shakeTimer    = 0.25;
  }

  void _updateFlipAnim(double dt) {
    if (!isFlipping) return;
    _flipAnimTimer += dt;
    flipProgress = (_flipAnimTimer / 0.55).clamp(0, 1);   // 0.55s transition
    if (flipProgress >= 1.0) {
      // Commit the flip
      isFlipping = false;
      flipProgress = 0;
      surface = surface == GravSurface.floor
          ? GravSurface.ceiling
          : GravSurface.floor;
      // Snap player to new surface
      if (surface == GravSurface.ceiling) {
        playerY  = GameConstants.ceilingY;
      } else {
        playerY  = GameConstants.groundY;
      }
      playerVY    = 0;
      _isOnGround = true;
      playerAction = PlayerAction.run;
    }
  }

  // ── Physics ───────────────────────────────────────────────────────────────

  void _updatePhysics(double dt) {
    if (isFlipping || _isOnGround) return;

    // Gravity pulls toward active surface
    final gravDir = surface == GravSurface.floor ? 1.0 : -1.0;
    playerVY += GameConstants.gravity * gravDir * dt;
    playerVY  = playerVY.clamp(-1400, 1400);

    playerY += (playerVY / screenHeight) * dt;

    // Land on surface
    if (surface == GravSurface.floor && playerY >= GameConstants.groundY) {
      playerY     = GameConstants.groundY;
      playerVY    = 0;
      _isOnGround = true;
      playerAction = PlayerAction.run;
    } else if (surface == GravSurface.ceiling && playerY <= GameConstants.ceilingY) {
      playerY     = GameConstants.ceilingY;
      playerVY    = 0;
      _isOnGround = true;
      playerAction = PlayerAction.run;
    }

    // Hit the opposite boundary = death
    if (surface == GravSurface.floor && playerY <= GameConstants.ceilingY) {
      _triggerDeath();
    } else if (surface == GravSurface.ceiling && playerY >= GameConstants.groundY) {
      _triggerDeath();
    }
  }

  // ── Obstacles ─────────────────────────────────────────────────────────────

  void _updateObstacles(double dt) {
    final speedMult = isVoidMode ? 0.5 : 1.0;
    final move = _currentSpeed * dt * speedMult / screenWidth;

    for (final o in obstacles) o.x -= move;
    obstacles.removeWhere((o) => o.x < -0.25);

    _obstacleTimer += dt;
    if (_obstacleTimer >= _obstacleInterval) {
      _spawnObstacle();
      _obstacleTimer    = 0;
      _obstacleInterval = max(0.85, _obstacleInterval - 0.015);
    }

    // Speed up
    if (score > 0 && score % GameConstants.speedEvery == 0) {
      _currentSpeed = GameConstants.baseSpeed +
          (score ~/ GameConstants.speedEvery) * GameConstants.speedStep;
    }
  }

  void _spawnObstacle() {
    // Don't spawn during or right after a flip
    if (isFlipping) return;

    final roll = _rng.nextInt(10);
    ObstacleKind kind;
    if (score < 6) {
      kind = roll < 6 ? ObstacleKind.lowBlock : ObstacleKind.highBlock;
    } else if (score < 20) {
      if (roll < 4) kind = ObstacleKind.lowBlock;
      else if (roll < 8) kind = ObstacleKind.highBlock;
      else kind = ObstacleKind.doubleBlock;
    } else {
      if (roll < 3) kind = ObstacleKind.lowBlock;
      else if (roll < 6) kind = ObstacleKind.highBlock;
      else if (roll < 8) kind = ObstacleKind.doubleBlock;
      else kind = ObstacleKind.voidRift;
    }

    obstacles.add(RunObstacle(x: 1.15, kind: kind));
  }

  // ── Collisions ────────────────────────────────────────────────────────────

  void _checkCollisions() {
    if (isFlipping) return;
    final isSliding = playerAction == PlayerAction.slide;
    const px    = 0.12;
    final pw    = GameConstants.playerW / screenWidth;
    final ph    = (isSliding ? GameConstants.slideHeight : GameConstants.playerH) / screenHeight;

    // Player bounding box (anchored to surface)
    double pTop, pBot;
    if (surface == GravSurface.floor) {
      pBot = playerY;
      pTop = playerY - ph;
    } else {
      pTop = playerY;
      pBot = playerY + ph;
    }
    final pLeft  = px;
    final pRight = px + pw;

    for (int i = 0; i < obstacles.length; i++) {
      final obs   = obstacles[i];
      final oLeft = obs.x;
      final oRight= obs.x + obsWidth(obs.kind) / screenWidth;

      // Horizontal overlap?
      if (pRight < oLeft || pLeft > oRight) continue;

      // Score passed
      if (!obs.passed && pLeft > oRight) {
        obstacles[i] = RunObstacle(x: obs.x, kind: obs.kind);
        _awardPoint(obs.kind);
        continue;
      }
      if (obs.passed) continue;

      // Void rift — pass through for energy
      if (obs.kind == ObstacleKind.voidRift) {
        obstacles[i].passed = true;
        voidEnergy = min(1.0, voidEnergy + 0.35);
        _spawnEnergyParticles();
        continue;
      }

      // Check vertical overlap with hitboxes
      final rects = obsHitboxes(obs, isSliding);
      for (final r in rects) {
        if (pBot > r[0] && pTop < r[1]) {
          _triggerDeath();
          return;
        }
      }
    }
  }

  double obsWidth(ObstacleKind k) {
    switch (k) {
      case ObstacleKind.doubleBlock: return 90;
      case ObstacleKind.voidRift:   return 50;
      default:                       return 52;
    }
  }

  // Returns list of [top, bottom] normalised hitboxes for an obstacle
  List<List<double>> obsHitboxes(RunObstacle obs, bool sliding) {
    // Obstacles adapt to current surface
    final isFloor = surface == GravSurface.floor;
    switch (obs.kind) {
      case ObstacleKind.lowBlock:
        // Short block — must slide under (or jump over trivially)
        final h = 0.14;
        final top    = isFloor ? GameConstants.groundY - h : GameConstants.ceilingY;
        final bottom = isFloor ? GameConstants.groundY     : GameConstants.ceilingY + h;
        return [[top, bottom]];
      case ObstacleKind.highBlock:
        // Tall block — must jump over
        final h = 0.28;
        final top    = isFloor ? GameConstants.groundY - h : GameConstants.ceilingY;
        final bottom = isFloor ? GameConstants.groundY     : GameConstants.ceilingY + h;
        return [[top, bottom]];
      case ObstacleKind.doubleBlock:
        // Two blocks with small gap between — slide under or over
        final h1 = 0.12;
        final h2 = 0.24;
        if (isFloor) {
          return [
            [GameConstants.groundY - h1, GameConstants.groundY],      // low block
            [GameConstants.groundY - h2 - 0.06, GameConstants.groundY - h1 - 0.06], // high piece
          ];
        } else {
          return [
            [GameConstants.ceilingY, GameConstants.ceilingY + h1],
            [GameConstants.ceilingY + h1 + 0.06, GameConstants.ceilingY + h1 + 0.06 + h2],
          ];
        }
      case ObstacleKind.voidRift:
        return []; // no collision
    }
  }

  void _triggerDeath() {
    _shakeTimer = 0.4;
    endGame();
  }

  void _awardPoint(ObstacleKind kind) {
    final pts = kind == ObstacleKind.doubleBlock ? 2 : 1;
    score += pts * multiplier;
    combo++;
    if (combo % 5 == 0) multiplier = min(multiplier + 1, 8);
    scorePopupValue = pts * multiplier;
    showScorePopup  = true;
    voidEnergy      = min(1.0, voidEnergy + 0.07);
    Future.delayed(const Duration(milliseconds: 600), () {
      showScorePopup = false;
      notifyListeners();
    });
  }

  // ── Particles ─────────────────────────────────────────────────────────────

  void _spawnJumpParticles() {
    final px = screenWidth * 0.12;
    final py = playerY * screenHeight;
    for (int i = 0; i < 10; i++) {
      final angle = _rng.nextDouble() * pi + (surface == GravSurface.floor ? pi : 0);
      final speed = 60 + _rng.nextDouble() * 100;
      particles.add(Particle(
        x: px, y: py, vx: cos(angle) * speed, vy: sin(angle) * speed,
        opacity: 1, scale: 0.5 + _rng.nextDouble() * 0.5,
        colorIndex: surface == GravSurface.floor ? 0 : 1, lifetime: 0.4,
      ));
    }
  }

  void _spawnFlipParticles() {
    for (int i = 0; i < 30; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 80 + _rng.nextDouble() * 200;
      particles.add(Particle(
        x: screenWidth * 0.5, y: screenHeight * 0.5,
        vx: cos(angle) * speed, vy: sin(angle) * speed,
        opacity: 1, scale: 0.4 + _rng.nextDouble() * 1.0,
        colorIndex: _rng.nextInt(3), lifetime: 0.7,
      ));
    }
  }

  void _spawnDeathParticles() {
    final px = screenWidth * 0.12;
    final py = playerY * screenHeight;
    for (int i = 0; i < 28; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 100 + _rng.nextDouble() * 280;
      particles.add(Particle(
        x: px, y: py, vx: cos(angle) * speed, vy: sin(angle) * speed,
        opacity: 1, scale: 0.5 + _rng.nextDouble() * 1.0,
        colorIndex: 3 + _rng.nextInt(2), lifetime: 1.2,
      ));
    }
  }

  void _spawnEnergyParticles() {
    final px = screenWidth * 0.12;
    final py = playerY * screenHeight;
    for (int i = 0; i < 10; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 60 + _rng.nextDouble() * 100;
      particles.add(Particle(
        x: px, y: py, vx: cos(angle) * speed, vy: sin(angle) * speed,
        opacity: 1, scale: 0.3 + _rng.nextDouble() * 0.5,
        colorIndex: 2, lifetime: 0.7,
      ));
    }
  }

  void _updateParticles(double dt) {
    for (final p in particles) {
      p.x  += p.vx * dt; p.y += p.vy * dt;
      p.vx *= 0.91;       p.vy *= 0.91;
      p.age += dt;
      p.opacity = max(0, 1 - p.age / p.lifetime);
    }
    particles.removeWhere((p) => p.age >= p.lifetime);
  }

  // ── Timers ────────────────────────────────────────────────────────────────

  void _updateTimers(double dt) {
    if (_shakeTimer > 0) {
      _shakeTimer -= dt;
      screenShake = _shakeTimer > 0 ? (_rng.nextDouble() - 0.5) * 14 : 0;
    }
    if (_loreTimer > 0) {
      _loreTimer -= dt;
      if (_loreTimer <= 0) showLoreMessage = false;
    }
    if (isVoidMode) {
      // Void mode drains energy over time
      voidEnergy -= dt * 0.2;
      if (voidEnergy <= 0) { voidEnergy = 0; isVoidMode = false; }
    }
  }

  // ── Lore ──────────────────────────────────────────────────────────────────

  void _updateLore(double dt) {
    for (final e in voidLore) {
      if (score >= e.threshold && !_triggeredLore.contains(e.threshold)) {
        _triggeredLore.add(e.threshold);
        activeLoreMessage = e.text;
        _loreTimer        = 3.5;
        showLoreMessage   = true;
      }
    }
  }

  @override
  void dispose() {
    _stopLoop();
    super.dispose();
  }
}
