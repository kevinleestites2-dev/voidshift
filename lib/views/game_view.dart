import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/game_engine.dart';
import 'game_painter.dart';
import 'shop_view.dart';
import 'leaderboard_view.dart';

class GameView extends StatefulWidget {
  const GameView({super.key});
  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView>
    with TickerProviderStateMixin {
  late GameEngine _engine;
  late AnimationController _bgAnimController;
  bool _showShop = false;
  bool _showLeaderboard = false;

  @override
  void initState() {
    super.initState();
    _engine = GameEngine();
    _engine.addListener(_onEngineUpdate);
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  void _onEngineUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngineUpdate);
    _engine.dispose();
    _bgAnimController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (_engine.gameState == GameState.menu) {
      _engine.startGame();
    } else if (_engine.gameState == GameState.playing) {
      _engine.handleTap();
    } else if (_engine.gameState == GameState.gameOver) {
      _engine.startGame();
    }
  }

  void _handleSwipeDown() {
    HapticFeedback.selectionClick();
    if (_engine.gameState == GameState.playing) {
      _engine.handleSwipeDown();
    }
  }

  void _handleSwipeUp() {
    HapticFeedback.selectionClick();
    if (_engine.gameState == GameState.playing) {
      _engine.handleSwipeUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _engine.screenWidth = constraints.maxWidth;
      _engine.screenHeight = constraints.maxHeight;

      return GestureDetector(
        onTapDown: (_) => _handleTap(),
        onVerticalDragEnd: (details) {
          final vel = details.primaryVelocity ?? 0;
          if (vel > 200) _handleSwipeDown();
          if (vel < -200) _handleSwipeUp();
        },
        child: Stack(
          children: [
            // Background
            AnimatedBuilder(
              animation: _bgAnimController,
              builder: (_, __) => CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: VoidBackgroundPainter(
                  _bgAnimController.value,
                  flipProgress: _engine.flipProgress,
                ),
              ),
            ),

            // HUD overlay (surface indicator + energy bar)
            if (_engine.gameState == GameState.playing)
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: HudPainter(_engine),
              ),

            // Game canvas
            if (_engine.gameState == GameState.playing ||
                _engine.gameState == GameState.gameOver)
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: GamePainter(_engine),
              ),

            // Score
            if (_engine.gameState == GameState.playing ||
                _engine.gameState == GameState.paused)
              _buildScore(constraints),

            // Menu
            if (_engine.gameState == GameState.menu && !_showShop && !_showLeaderboard)
              _buildMenu(constraints),

            // Shop overlay
            if (_showShop)
              ShopView(engine: _engine, onClose: () => setState(() => _showShop = false)),

            // Leaderboard overlay
            if (_showLeaderboard)
              LeaderboardView(
                playerHighScore: _engine.highScore,
                onClose: () => setState(() => _showLeaderboard = false),
              ),

            // Game Over
            if (_engine.gameState == GameState.gameOver)
              _buildGameOver(constraints),

            // Lore message
            if (_engine.showLoreMessage && _engine.activeLoreMessage != null)
              _buildLoreMessage(constraints),

            // Score popup
            if (_engine.showScorePopup) _buildScorePopup(constraints),
          ],
        ),
      );
    });
  }

  Widget _buildScore(BoxConstraints c) {
    return Positioned(
      top: 48,
      left: 0, right: 0,
      child: Column(
        children: [
          Text(
            '${_engine.score}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              shadows: [Shadow(color: Color(0xFF00CFFF), blurRadius: 16)],
            ),
          ),
          if (_engine.multiplier > 1)
            Text(
              'x${_engine.multiplier}',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenu(BoxConstraints c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF00CFFF), Color(0xFF9B59FF), Color(0xFFFFD700)],
            ).createShader(bounds),
            child: const Text(
              'VOID\nSHIFT',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.w900,
                letterSpacing: 10,
                height: 0.9,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'PARKOUR · FLIP · SURVIVE',
            style: TextStyle(
              color: const Color(0xFF00CFFF).withOpacity(0.7),
              fontSize: 12,
              letterSpacing: 6,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 60),
          if (_engine.highScore > 0) ...[
            Text(
              'BEST  ${_engine.highScore}',
              style: TextStyle(
                color: const Color(0xFFFFD700).withOpacity(0.8),
                fontSize: 16,
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
          ],
          // Tap hint pulse
          _PulsatingText(text: 'TAP TO ENTER THE VOID'),
          const SizedBox(height: 60),
          Text(
            'tap = jump  ·  swipe ↓ = slide  ·  world flips',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 11,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 40),
          // Bottom nav
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MenuIconBtn(
                icon: Icons.storefront,
                label: 'SHOP',
                color: const Color(0xFFFFD700),
                onTap: () => setState(() => _showShop = true),
              ),
              const SizedBox(width: 40),
              _MenuIconBtn(
                icon: Icons.leaderboard,
                label: 'RANKS',
                color: const Color(0xFF00CFFF),
                onTap: () => setState(() => _showLeaderboard = true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameOver(BoxConstraints c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'YOU FELL',
            style: TextStyle(
              color: const Color(0xFFFF4444).withOpacity(0.9),
              fontSize: 14,
              letterSpacing: 8,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_engine.score}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 72,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              shadows: [Shadow(color: Color(0xFF00CFFF), blurRadius: 24)],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'BEST  ${_engine.highScore}',
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 16,
              letterSpacing: 4,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '+${_engine.coinsEarnedThisRun} VOID COINS',
            style: TextStyle(
              color: const Color(0xFFFFD700).withOpacity(0.7),
              fontSize: 13,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 48),
          _PulsatingText(text: 'TAP TO SHIFT AGAIN'),
        ],
      ),
    );
  }

  Widget _buildLoreMessage(BoxConstraints c) {
    return Positioned(
      bottom: c.maxHeight * 0.25,
      left: 32, right: 32,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          border: Border.all(
            color: const Color(0xFF00CFFF).withOpacity(0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _engine.activeLoreMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF00CFFF).withOpacity(0.85),
            fontSize: 13,
            height: 1.6,
            letterSpacing: 1,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildScorePopup(BoxConstraints c) {
    return Positioned(
      top: c.maxHeight * 0.35,
      left: 0, right: 0,
      child: Center(
        child: Text(
          '+${_engine.scorePopupValue}',
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Color(0xFFFFD700), blurRadius: 12)],
          ),
        ),
      ),
    );
  }
}

// ─── Menu Icon Button ─────────────────────────────────────────────────────────
class _MenuIconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuIconBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 9, letterSpacing: 3, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

// ─── Pulsating text widget ────────────────────────────────────────────────────
class _PulsatingText extends StatefulWidget {
  final String text;
  const _PulsatingText({required this.text});
  @override
  State<_PulsatingText> createState() => _PulsatingTextState();
}

class _PulsatingTextState extends State<_PulsatingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Text(
        widget.text,
        style: TextStyle(
          color: Colors.white.withOpacity(_anim.value),
          fontSize: 14,
          letterSpacing: 5,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}
