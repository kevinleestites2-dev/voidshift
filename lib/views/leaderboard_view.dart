import 'package:flutter/material.dart';
import '../models/skins.dart';
import 'shop_view.dart';

class LeaderboardView extends StatelessWidget {
  final int playerHighScore;
  final VoidCallback onClose;

  const LeaderboardView({
    super.key,
    required this.playerHighScore,
    required this.onClose,
  });

  List<LeaderboardEntry> get _entries {
    final board = List<LeaderboardEntry>.from(LeaderboardEntry.mock);
    if (playerHighScore > 0) {
      board.add(LeaderboardEntry(
        id: 'player',
        playerName: 'YOU',
        score: playerHighScore,
        date: DateTime.now(),
      ));
    }
    board.sort((a, b) => b.score.compareTo(a.score));
    for (int i = 0; i < board.length; i++) {
      board[i].rank = i + 1;
    }
    return board;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final playerEntry = entries.firstWhere(
      (e) => e.id == 'player',
      orElse: () => LeaderboardEntry(id: '', playerName: '', score: 0, date: DateTime.now()),
    );

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
                      onTap: onClose,
                      child: const Icon(Icons.close, color: VTheme.textSecond, size: 22),
                    ),
                    const Spacer(),
                    Text('LEADERBOARD', style: VTheme.heading()),
                    const Spacer(),
                    if (playerEntry.rank > 0)
                      Text(
                        '#${playerEntry.rank}',
                        style: VTheme.mono(size: 14).copyWith(color: VTheme.cyan, fontWeight: FontWeight.bold),
                      )
                    else
                      const SizedBox(width: 28),
                  ],
                ),
              ),

              // Top 3 podium
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildPodium(entries),
              ),

              // Divider
              Container(height: 1, color: VTheme.cyan.withOpacity(0.12), margin: const EdgeInsets.symmetric(horizontal: 20)),
              const SizedBox(height: 8),

              // Rest of list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: entries.length > 3 ? entries.length - 3 : 0,
                  itemBuilder: (_, i) {
                    final entry = entries[i + 3];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _LeaderboardRow(
                        entry: entry,
                        isPlayer: entry.id == 'player',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();

    Widget podiumCard(LeaderboardEntry e, double height, Color crown) {
      final isPlayer = e.id == 'player';
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (e.rank == 1)
              Icon(Icons.star, color: VTheme.gold, size: 22),
            const SizedBox(height: 4),
            Text(
              e.rank <= entries.length ? '#${e.rank}' : '',
              style: VTheme.mono(size: 11).copyWith(color: crown),
            ),
            const SizedBox(height: 4),
            Text(
              e.playerName,
              style: VTheme.mono(size: 13).copyWith(
                color: isPlayer ? VTheme.cyan : Colors.white,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text('${e.score}', style: VTheme.mono(size: 16).copyWith(color: crown, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: height,
              decoration: BoxDecoration(
                color: crown.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                border: Border.all(color: crown.withOpacity(0.5)),
              ),
            ),
          ],
        ),
      );
    }

    final e1 = entries.isNotEmpty ? entries[0] : null;
    final e2 = entries.length > 1 ? entries[1] : null;
    final e3 = entries.length > 2 ? entries[2] : null;

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (e2 != null) podiumCard(e2, 90, const Color(0xFFC0C0C0)),
          const SizedBox(width: 8),
          if (e1 != null) podiumCard(e1, 130, VTheme.gold),
          const SizedBox(width: 8),
          if (e3 != null) podiumCard(e3, 70, const Color(0xFFCD7F32)),
        ],
      ),
    );
  }
}

// ─── Row ──────────────────────────────────────────────────────────────────────
class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isPlayer;

  const _LeaderboardRow({required this.entry, required this.isPlayer});

  Color get _rankColor {
    switch (entry.rank) {
      case 1: return VTheme.gold;
      case 2: return const Color(0xFFC0C0C0);
      case 3: return const Color(0xFFCD7F32);
      default: return VTheme.textSecond;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isPlayer ? VTheme.cyan.withOpacity(0.08) : const Color(0xFF0D0820),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlayer ? VTheme.cyan.withOpacity(0.5) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('#${entry.rank}', style: VTheme.mono(size: 14).copyWith(color: _rankColor)),
          ),
          if (entry.rank <= 3)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.emoji_events, color: VTheme.gold, size: 16),
            )
          else
            const SizedBox(width: 24),
          Expanded(
            child: Text(
              entry.playerName,
              style: VTheme.mono(size: 15).copyWith(
                color: isPlayer ? VTheme.cyan : Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${entry.score}',
            style: VTheme.mono(size: 18).copyWith(
              color: isPlayer ? VTheme.cyan : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
