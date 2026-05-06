import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
class GameConstants {
  static const double playerSize = 28;
  static const double obstacleWidth = 60;
  static const double gapSize = 180;
  static const double baseSpeed = 220;
  static const double speedIncrement = 12;
  static const int speedIncreaseInterval = 8;
  static const double gravityStrength = 900;
  static const double jumpImpulse = -520;
  static const double groundY = 0.85;
  static const double ceilingY = 0.08;
}

// ─── Enums ───────────────────────────────────────────────────────────────────
enum GameState { menu, playing, paused, gameOver }

enum GravityDirection { down, up }

// ─── Models ──────────────────────────────────────────────────────────────────
class Obstacle {
  final String id;
  double x;
  final double gapY;
  final double gapSize;
  bool passed;
  final bool isVoidRift;

  Obstacle({
    required this.x,
    required this.gapY,
    required this.gapSize,
    this.passed = false,
    this.isVoidRift = false,
  }) : id = _uuid();

  static int _counter = 0;
  static String _uuid() => 'obs_${_counter++}';
}

class Particle {
  final String id;
  double x, y;
  double vx, vy;
  double opacity;
  double scale;
  final int colorIndex; // 0=cyan, 1=purple, 2=yellow, 3=red, 4=orange
  final double lifetime;
  double age;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.opacity,
    required this.scale,
    required this.colorIndex,
    required this.lifetime,
    this.age = 0,
  }) : id = _uuid();

  static int _counter = 0;
  static String _uuid() => 'p_${_counter++}';
}

// ─── Lore ────────────────────────────────────────────────────────────────────
class LoreEntry {
  final int threshold;
  final String text;
  LoreEntry(this.threshold, this.text);
}

final List<LoreEntry> voidLore = [
  LoreEntry(5,  "you entered the void.\nit noticed."),
  LoreEntry(10, "the void remembers every flip.\nevery single one."),
  LoreEntry(20, "others came before you.\nthey did not last."),
  LoreEntry(35, "you are becoming something.\nthe void is not sure what."),
  LoreEntry(50, "halfway to nowhere.\nthe void is impressed."),
  LoreEntry(75, "the void is testing you now.\nfor real this time."),
  LoreEntry(100,"you have survived long enough\nto be considered dangerous."),
];

// ─── Game Engine ─────────────────────────────────────────────────────────────
class GameEngine extends ChangeNotifier {
  // State
  GameState gameState = GameState.menu;
  int score = 0;
  int highScore = 0;
  double playerY = 0.5;
  double playerVelocity = 0;
  GravityDirection gravityDirection = GravityDirection.down;
  List<Obstacle> obstacles = [];
  List<Particle> particles = [];
  double screenShake = 0;
  bool isInvincible = false;
  int combo = 0;
  int multiplier = 1;
  double voidEnergy = 0;
  bool isVoidMode = false;
  bool showScorePopup = false;
  int scorePopupValue = 0;
  int coinsEarnedThisRun = 0;
  int totalCoins = 0;

  // Lore
  String? activeLoreMessage;
  bool showLoreMessage = false;

  // Screen dims
  double screenWidth = 390;
  double screenHeight = 844;

  // Private
  Timer? _loopTimer;
  DateTime _lastTime = DateTime.now();
  double _obstacleSpawnTimer = 0;
  double _obstacleSpawnInterval = 1.8;
  double _currentSpeed = GameConstants.baseSpeed;
  double _invincibleTimer = 0;
  double _voidModeTimer = 0;
  double _shakeTimer = 0;
  double _loreTimer = 0;
  int _flipCountThisRun = 0;
  Set<int> _triggeredLoreScores = {};

  final Random _rng = Random();

  // ── Control ────────────────────────────────────────────────────────────────

  void startGame() {
    score = 0;
    playerY = 0.5;
    playerVelocity = 0;
    gravityDirection = GravityDirection.down;
    obstacles = [];
    particles = [];
    _currentSpeed = GameConstants.baseSpeed;
    _obstacleSpawnTimer = 0;
    _obstacleSpawnInterval = 1.8;
    combo = 0;
    multiplier = 1;
    voidEnergy = 0;
    isVoidMode = false;
    isInvincible = false;
    coinsEarnedThisRun = 0;
    _flipCountThisRun = 0;
    _triggeredLoreScores = {};
    activeLoreMessage = null;
    showLoreMessage = false;
    gameState = GameState.playing;
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
    _spawnDeathParticles();
    gameState = GameState.gameOver;
    notifyListeners();
  }

  void handleTap() {
    if (gameState == GameState.playing) flipGravity();
  }

  void flipGravity() {
    gravityDirection = gravityDirection == GravityDirection.down
        ? GravityDirection.up
        : GravityDirection.down;
    playerVelocity = GameConstants.jumpImpulse *
        (gravityDirection == GravityDirection.up ? 1 : -1);
    _spawnFlipParticles();
    combo++;
    _flipCountThisRun++;
    if (combo % 5 == 0) multiplier = min(multiplier + 1, 8);
    if (_flipCountThisRun == 100) {
      _triggerLore(
          "the void counted your flips.\nyou flipped a hundred times without stopping.\nit found that... interesting.");
    }
    notifyListeners();
  }

  void activateVoidMode() {
    if (voidEnergy < 1.0) return;
    isVoidMode = true;
    _voidModeTimer = 5.0;
    voidEnergy = 0;
    notifyListeners();
  }

  // ── Loop ───────────────────────────────────────────────────────────────────

  void _startLoop() {
    _lastTime = DateTime.now();
    _loopTimer =
        Timer.periodic(const Duration(microseconds: 16667), (_) => _update());
  }

  void _stopLoop() {
    _loopTimer?.cancel();
    _loopTimer = null;
  }

  void _update() {
    final now = DateTime.now();
    final dt = min(now.difference(_lastTime).inMicroseconds / 1000000.0, 0.05);
    _lastTime = now;
    if (gameState != GameState.playing) return;

    _updatePhysics(dt);
    _updateObstacles(dt);
    _updateParticles(dt);
    _updateTimers(dt);
    _checkCollisions();
    _updateLore(dt);
    notifyListeners();
  }

  // ── Physics ────────────────────────────────────────────────────────────────

  void _updatePhysics(double dt) {
    final gravity = GameConstants.gravityStrength *
        (gravityDirection == GravityDirection.down ? 1 : -1);
    playerVelocity += gravity * dt;
    playerVelocity = playerVelocity.clamp(-900, 900);
    final normalizedVelocity = playerVelocity / screenHeight;
    playerY += normalizedVelocity * dt;

    if (playerY >= GameConstants.groundY || playerY <= GameConstants.ceilingY) {
      endGame();
    }
  }

  // ── Obstacles ──────────────────────────────────────────────────────────────

  void _updateObstacles(double dt) {
    final speedMult = isVoidMode ? 0.5 : 1.0;
    final moveAmount = _currentSpeed * dt * speedMult / screenWidth;

    for (final obs in obstacles) {
      obs.x -= moveAmount;
    }
    obstacles.removeWhere((o) => o.x < -0.15);

    _obstacleSpawnTimer += dt;
    if (_obstacleSpawnTimer >= _obstacleSpawnInterval) {
      _spawnObstacle();
      _obstacleSpawnTimer = 0;
      _obstacleSpawnInterval = max(0.9, _obstacleSpawnInterval - 0.02);
    }

    if (score > 0 && score % GameConstants.speedIncreaseInterval == 0) {
      _currentSpeed = GameConstants.baseSpeed +
          (score ~/ GameConstants.speedIncreaseInterval) *
              GameConstants.speedIncrement;
    }
  }

  void _spawnObstacle() {
    final isRift = _rng.nextInt(8) == 0 && score > 20;
    final gapCenter = 0.2 + _rng.nextDouble() * 0.6;
    final gapSz = max(0.15, 0.22 - score * 0.001);
    obstacles.add(Obstacle(
      x: 1.1,
      gapY: gapCenter,
      gapSize: gapSz,
      isVoidRift: isRift,
    ));
  }

  // ── Collisions ─────────────────────────────────────────────────────────────

  void _checkCollisions() {
    if (isInvincible) return;
    const px = 0.15;
    final playerRadius = GameConstants.playerSize / 2 / screenWidth;
    final playerRadiusY = GameConstants.playerSize / 2 / screenHeight;

    for (int i = 0; i < obstacles.length; i++) {
      final obs = obstacles[i];
      final obsLeft = obs.x;
      final obsRight = obs.x + GameConstants.obstacleWidth / screenWidth;

      if (px + playerRadius <= obsLeft || px - playerRadius >= obsRight) {
        continue;
      }

      final gapTop = obs.gapY - obs.gapSize / 2;
      final gapBottom = obs.gapY + obs.gapSize / 2;

      if (playerY - playerRadiusY < gapTop ||
          playerY + playerRadiusY > gapBottom) {
        if (obs.isVoidRift && !obs.passed) {
          voidEnergy = min(1.0, voidEnergy + 0.3);
          obstacles[i].passed = true;
          _spawnEnergyParticles();
        } else {
          _triggerDeath();
          return;
        }
      }

      if (!obs.passed && px > obsRight) {
        obstacles[i].passed = true;
        _awardPoint();
      }
    }
  }

  void _triggerDeath() {
    _shakeTimer = 0.4;
    endGame();
  }

  void _awardPoint() {
    score += multiplier;
    scorePopupValue = multiplier;
    showScorePopup = true;
    Future.delayed(const Duration(milliseconds: 600), () {
      showScorePopup = false;
      notifyListeners();
    });
    voidEnergy = min(1.0, voidEnergy + 0.08);
  }

  // ── Particles ──────────────────────────────────────────────────────────────

  void _spawnFlipParticles() {
    final px = screenWidth * 0.15;
    final py = playerY * screenHeight;
    final colorIdx = gravityDirection == GravityDirection.down ? 0 : 1;
    for (int i = 0; i < 12; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 80 + _rng.nextDouble() * 120;
      particles.add(Particle(
        x: px, y: py,
        vx: cos(angle) * speed, vy: sin(angle) * speed,
        opacity: 1.0,
        scale: 0.4 + _rng.nextDouble() * 0.6,
        colorIndex: colorIdx,
        lifetime: 0.5,
      ));
    }
  }

  void _spawnDeathParticles() {
    final px = screenWidth * 0.15;
    final py = playerY * screenHeight;
    final colors = [3, 4, 5]; // red, orange, yellow
    for (int i = 0; i < 25; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 100 + _rng.nextDouble() * 250;
      particles.add(Particle(
        x: px, y: py,
        vx: cos(angle) * speed, vy: sin(angle) * speed,
        opacity: 1.0,
        scale: 0.5 + _rng.nextDouble() * 1.0,
        colorIndex: colors[_rng.nextInt(colors.length)],
        lifetime: 1.2,
      ));
    }
  }

  void _spawnEnergyParticles() {
    final px = screenWidth * 0.15;
    final py = playerY * screenHeight;
    for (int i = 0; i < 8; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 60 + _rng.nextDouble() * 90;
      particles.add(Particle(
        x: px, y: py,
        vx: cos(angle) * speed, vy: sin(angle) * speed,
        opacity: 1.0,
        scale: 0.3 + _rng.nextDouble() * 0.5,
        colorIndex: 2, // yellow
        lifetime: 0.7,
      ));
    }
  }

  void _updateParticles(double dt) {
    for (final p in particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 0.92;
      p.vy *= 0.92;
      p.age += dt;
      p.opacity = max(0, 1 - p.age / p.lifetime);
    }
    particles.removeWhere((p) => p.age >= p.lifetime);
  }

  // ── Timers ─────────────────────────────────────────────────────────────────

  void _updateTimers(double dt) {
    if (_invincibleTimer > 0) {
      _invincibleTimer -= dt;
      if (_invincibleTimer <= 0) isInvincible = false;
    }
    if (_voidModeTimer > 0) {
      _voidModeTimer -= dt;
      if (_voidModeTimer <= 0) isVoidMode = false;
    }
    if (_shakeTimer > 0) {
      _shakeTimer -= dt;
      screenShake = _shakeTimer > 0 ? (_rng.nextDouble() - 0.5) * 16 : 0;
    }
    if (_loreTimer > 0) {
      _loreTimer -= dt;
      if (_loreTimer <= 0) showLoreMessage = false;
    }
  }

  // ── Lore ───────────────────────────────────────────────────────────────────

  void _updateLore(double dt) {
    for (final entry in voidLore) {
      if (score >= entry.threshold &&
          !_triggeredLoreScores.contains(entry.threshold)) {
        _triggeredLoreScores.add(entry.threshold);
        _triggerLore(entry.text);
      }
    }
  }

  void _triggerLore(String text, {double duration = 3.5}) {
    activeLoreMessage = text;
    _loreTimer = duration;
    showLoreMessage = true;
  }

  @override
  void dispose() {
    _stopLoop();
    super.dispose();
  }
}
