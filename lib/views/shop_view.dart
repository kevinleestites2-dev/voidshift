import 'package:flutter/material.dart';
import '../models/skins.dart';
import '../engine/game_engine.dart';

// ─── Theme ────────────────────────────────────────────────────────────────────
class VTheme {
  static const cyan = Color(0xFF00CFFF);
  static const purple = Color(0xFF9B59FF);
  static const gold = Color(0xFFFFD700);
  static const surface = Color(0xFF0D0820);
  static const textSecond = Color(0xFF8888AA);
  static const voidRed = Color(0xFFFF4444);

  static TextStyle heading({double size = 15}) => TextStyle(
    color: Colors.white,
    fontSize: size,
    fontWeight: FontWeight.w900,
    letterSpacing: 3,
    fontFamily: 'monospace',
  );

  static TextStyle mono({double size = 13}) => TextStyle(
    color: Colors.white,
    fontSize: size,
    fontFamily: 'monospace',
    letterSpacing: 1,
  );
}

// ─── Shop Screen ──────────────────────────────────────────────────────────────
class ShopView extends StatefulWidget {
  final GameEngine engine;
  final VoidCallback onClose;

  const ShopView({super.key, required this.engine, required this.onClose});

  @override
  State<ShopView> createState() => _ShopViewState();
}

class _ShopViewState extends State<ShopView> {
  String? _selectedSkinId;
  bool _showConfirm = false;
  Skin? _confirmSkin;
  String _buyMessage = '';
  bool _showSuccess = false;

  final List<Map<String, dynamic>> _coinPacks = [
    {'label': 'SPARK', 'coins': 100, 'price': '\$0.99', 'color': Color(0xFF00CFFF), 'badge': null},
    {'label': 'SURGE', 'coins': 300, 'price': '\$1.99', 'color': Color(0xFF9B59FF), 'badge': 'POPULAR'},
    {'label': 'STORM', 'coins': 750, 'price': '\$3.99', 'color': Color(0xFFFFD700), 'badge': null},
    {'label': 'NOVA',  'coins': 2000,'price': '\$9.99', 'color': Color(0xFFFF8C00), 'badge': 'BEST VALUE'},
  ];

  @override
  Widget build(BuildContext context) {
    final skins = Skin.all;
    final coins = widget.engine.totalCoins;

    return Stack(
      children: [
        // BG
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF050010), Color(0xFF0A0020)],
            ),
          ),
        ),

        SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onClose,
                      child: const Icon(Icons.close, color: VTheme.textSecond, size: 22),
                    ),
                    const Spacer(),
                    Text('VOID SHOP', style: VTheme.heading()),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.circle, color: VTheme.gold, size: 12),
                        const SizedBox(width: 4),
                        Text('$coins', style: VTheme.mono().copyWith(color: VTheme.gold, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Skins section
                      Text('SKINS', style: VTheme.heading(size: 12).copyWith(color: VTheme.textSecond)),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: skins.length,
                        itemBuilder: (_, i) {
                          final skin = skins[i];
                          final unlocked = skin.isUnlocked || skin.price == 0;
                          final selected = _selectedSkinId == skin.id || (skin.id == 'default' && _selectedSkinId == null);
                          return _SkinCard(
                            skin: skin,
                            isUnlocked: unlocked,
                            isSelected: selected,
                            onTap: () {
                              if (unlocked) {
                                setState(() => _selectedSkinId = skin.id);
                              } else {
                                setState(() {
                                  _confirmSkin = skin;
                                  _buyMessage = '';
                                  _showConfirm = true;
                                });
                              }
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 28),

                      // Divider
                      Container(height: 1, color: VTheme.cyan.withOpacity(0.15)),
                      const SizedBox(height: 20),

                      // Coin packs
                      Row(
                        children: [
                          const Icon(Icons.circle, color: VTheme.gold, size: 13),
                          const SizedBox(width: 6),
                          Text('GET COINS', style: VTheme.heading(size: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      ..._coinPacks.map((pack) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CoinPackRow(
                          label: pack['label'],
                          coins: pack['coins'],
                          price: pack['price'],
                          color: pack['color'],
                          badge: pack['badge'],
                          onTap: () {
                            // IAP hook — for web demo just add coins
                            setState(() {
                              widget.engine.totalCoins += (pack['coins'] as int);
                              _showSuccess = true;
                            });
                            Future.delayed(const Duration(seconds: 2), () {
                              if (mounted) setState(() => _showSuccess = false);
                            });
                          },
                        ),
                      )),

                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Buy confirm overlay
        if (_showConfirm && _confirmSkin != null) ...[
          GestureDetector(
            onTap: () => setState(() => _showConfirm = false),
            child: Container(color: Colors.black.withOpacity(0.7)),
          ),
          Center(
            child: _BuyConfirmPanel(
              skin: _confirmSkin!,
              buyMessage: _buyMessage,
              onCancel: () => setState(() => _showConfirm = false),
              onBuy: () {
                if (widget.engine.totalCoins >= _confirmSkin!.price) {
                  setState(() {
                    widget.engine.totalCoins -= _confirmSkin!.price;
                    _confirmSkin!.isUnlocked = true;
                    _selectedSkinId = _confirmSkin!.id;
                    _showConfirm = false;
                    _showSuccess = true;
                  });
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) setState(() => _showSuccess = false);
                  });
                } else {
                  setState(() => _buyMessage = 'Not enough coins!');
                }
              },
            ),
          ),
        ],

        // Success toast
        if (_showSuccess)
          Positioned(
            bottom: 60,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: VTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: VTheme.gold.withOpacity(0.6), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: VTheme.gold, size: 14),
                    const SizedBox(width: 8),
                    Text('Unlocked!', style: VTheme.mono().copyWith(color: Colors.white, fontSize: 15)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Skin Card ────────────────────────────────────────────────────────────────
class _SkinCard extends StatelessWidget {
  final Skin skin;
  final bool isUnlocked;
  final bool isSelected;
  final VoidCallback onTap;

  const _SkinCard({
    required this.skin,
    required this.isUnlocked,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: VTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? VTheme.gold
                : isUnlocked
                    ? skin.primary.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: skin.primary.withOpacity(0.15),
                  ),
                ),
                Icon(
                  isUnlocked ? Icons.circle : Icons.lock,
                  color: isUnlocked ? skin.primary : Colors.grey,
                  size: 32,
                ),
                // Custom colored orb
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.white.withOpacity(0.9), skin.primary],
                    ),
                    boxShadow: [BoxShadow(color: skin.primary.withOpacity(0.5), blurRadius: 12)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(skin.name, style: VTheme.mono(size: 13).copyWith(
              color: isUnlocked ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 4),
            if (!isUnlocked)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.circle, color: VTheme.gold, size: 9),
                  const SizedBox(width: 3),
                  Text('${skin.price}', style: VTheme.mono(size: 12).copyWith(color: VTheme.gold)),
                ],
              )
            else
              Text(
                isSelected ? 'EQUIPPED' : 'EQUIP',
                style: VTheme.mono(size: 11).copyWith(
                  color: isSelected ? VTheme.gold : VTheme.cyan,
                  letterSpacing: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Coin Pack Row ────────────────────────────────────────────────────────────
class _CoinPackRow extends StatelessWidget {
  final String label;
  final int coins;
  final String price;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _CoinPackRow({
    required this.label,
    required this.coins,
    required this.price,
    required this.color,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: VTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
              child: Icon(Icons.bolt, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label, style: VTheme.heading(size: 14)),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                        child: Text(badge!, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.circle, color: VTheme.gold, size: 9),
                    const SizedBox(width: 3),
                    Text('$coins coins', style: VTheme.mono(size: 12).copyWith(color: VTheme.gold)),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: Text(price, style: VTheme.heading(size: 14).copyWith(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Buy Confirm Panel ────────────────────────────────────────────────────────
class _BuyConfirmPanel extends StatelessWidget {
  final Skin skin;
  final String buyMessage;
  final VoidCallback onCancel;
  final VoidCallback onBuy;

  const _BuyConfirmPanel({
    required this.skin,
    required this.buyMessage,
    required this.onCancel,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: VTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: skin.primary.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(skin.name, style: VTheme.heading()),
            const SizedBox(height: 8),
            Text(skin.description, style: VTheme.mono().copyWith(color: VTheme.textSecond), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.circle, color: VTheme.gold, size: 14),
                const SizedBox(width: 4),
                Text('${skin.price} coins', style: VTheme.mono(size: 16).copyWith(color: VTheme.gold)),
              ],
            ),
            if (buyMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(buyMessage, style: VTheme.mono(size: 13).copyWith(color: VTheme.voidRed)),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: onCancel, child: Text('Cancel', style: VTheme.mono().copyWith(color: VTheme.textSecond))),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: onBuy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VTheme.gold,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('BUY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
