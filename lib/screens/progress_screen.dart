import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../services/game_analyzer.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with SingleTickerProviderStateMixin {
  List<GameRecord> _games = [];
  bool _loading = true;
  late TabController _tabController;
  int _selectedPeriod = 2; // 0=Week, 1=Month, 2=All

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 2);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedPeriod = _tabController.index);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final games = await GameAnalyzer().loadGames(limit: 500);
    if (mounted) setState(() { _games = games.reversed.toList(); _loading = false; });
  }

  List<GameRecord> get _filtered {
    if (_selectedPeriod == 2) return _games;
    final now = DateTime.now();
    final cutoff = _selectedPeriod == 0
        ? now.subtract(const Duration(days: 7))
        : now.subtract(const Duration(days: 30));
    return _games.where((g) => g.playedAt.isAfter(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        title: const Text('My Progress'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFF4B942),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFFF4B942),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'This Week'),
            Tab(text: 'This Month'),
            Tab(text: 'All Time'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF4B942)))
          : _games.isEmpty
              ? _EmptyState()
              : _ProgressBody(games: _filtered, allGames: _games),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('♟', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text('No games yet', style: TextStyle(color: Colors.white54, fontSize: 18)),
          SizedBox(height: 8),
          Text('Play a game to start tracking your progress!',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ProgressBody extends StatelessWidget {
  final List<GameRecord> games;
  final List<GameRecord> allGames;
  const _ProgressBody({required this.games, required this.allGames});

  int get _wins => games.where((g) => g.result == GameStatus.checkmate).length;
  int get _losses => games.where((g) => g.result == GameStatus.resigned).length;
  int get _draws => games.where((g) =>
      g.result == GameStatus.stalemate || g.result == GameStatus.draw).length;

  int get _avgScore {
    if (games.isEmpty) return 0;
    return games.map((g) => g.performanceScore).reduce((a, b) => a + b) ~/ games.length;
  }

  int get _bestScore {
    if (games.isEmpty) return 0;
    return games.map((g) => g.performanceScore).reduce((a, b) => a > b ? a : b);
  }

  double get _recentTrend {
    if (games.length < 2) return 0;
    final recent = games.length > 10 ? games.sublist(games.length - 10) : games;
    if (recent.length < 2) return 0;
    final half = recent.length ~/ 2;
    final firstHalf = recent.sublist(0, half);
    final secondHalf = recent.sublist(half);
    final firstAvg = firstHalf.map((g) => g.performanceScore).reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.map((g) => g.performanceScore).reduce((a, b) => a + b) / secondHalf.length;
    return secondAvg - firstAvg;
  }

  // Play streak: consecutive days (from today backward) with at least one game
  int get _playStreak {
    if (allGames.isEmpty) return 0;
    final gameDays = allGames.map((g) {
      final d = g.playedAt;
      return DateTime(d.year, d.month, d.day);
    }).toSet();

    int streak = 0;
    var day = DateTime.now();
    day = DateTime(day.year, day.month, day.day);

    // Allow today or yesterday to start the streak
    if (!gameDays.contains(day)) {
      day = day.subtract(const Duration(days: 1));
    }

    while (gameDays.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // Win streak: consecutive wins from most recent game
  int get _winStreak {
    int streak = 0;
    for (final g in allGames.reversed) {
      if (g.result == GameStatus.checkmate) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('♟', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No games in this period', style: TextStyle(color: Colors.white54, fontSize: 16)),
            SizedBox(height: 6),
            Text('Try selecting a wider time range', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary stats row
          Row(
            children: [
              _StatBadge(value: '${games.length}', label: 'Games', color: Colors.white70),
              const SizedBox(width: 10),
              _StatBadge(value: '$_avgScore', label: 'Avg Score', color: const Color(0xFFF4B942)),
              const SizedBox(width: 10),
              _StatBadge(value: '$_bestScore', label: 'Best', color: Colors.greenAccent),
            ],
          ),

          const SizedBox(height: 12),

          // Streaks row
          _StreaksCard(playStreak: _playStreak, winStreak: _winStreak),

          const SizedBox(height: 12),

          // Trend indicator
          _TrendCard(trend: _recentTrend, gamesCount: games.length),

          const SizedBox(height: 12),

          // Win/Loss/Draw
          _WinRateCard(wins: _wins, losses: _losses, draws: _draws, total: games.length),

          const SizedBox(height: 12),

          // Score chart
          _SectionHeader(title: 'Performance Over Time'),
          const SizedBox(height: 8),
          _ScoreChart(games: games),

          const SizedBox(height: 12),

          // Achievements
          _SectionHeader(title: 'Achievements'),
          const SizedBox(height: 8),
          _AchievementsCard(allGames: allGames),

          const SizedBox(height: 12),

          // Difficulty breakdown
          _SectionHeader(title: 'Difficulty Breakdown'),
          const SizedBox(height: 8),
          _DifficultyBreakdown(games: games),

          const SizedBox(height: 12),

          // Recent 5 games
          _SectionHeader(title: 'Recent Games'),
          const SizedBox(height: 8),
          ...games.reversed.take(5).map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RecentGameRow(record: g),
              )),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFF4B942),
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatBadge({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2137),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1E3A5F)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _StreaksCard extends StatelessWidget {
  final int playStreak;
  final int winStreak;
  const _StreaksCard({required this.playStreak, required this.winStreak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(
        children: [
          Expanded(child: _StreakItem(icon: '🔥', value: playStreak, label: 'Day Streak')),
          Container(width: 1, height: 40, color: const Color(0xFF1E3A5F)),
          Expanded(child: _StreakItem(icon: '⚡', value: winStreak, label: 'Win Streak')),
        ],
      ),
    );
  }
}

class _StreakItem extends StatelessWidget {
  final String icon;
  final int value;
  final String label;
  const _StreakItem({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final active = value > 0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              '$value',
              style: TextStyle(
                color: active ? const Color(0xFFF4B942) : Colors.white38,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  final double trend;
  final int gamesCount;
  const _TrendCard({required this.trend, required this.gamesCount});

  @override
  Widget build(BuildContext context) {
    final improving = trend > 1;
    final declining = trend < -1;
    final color = improving ? Colors.greenAccent : declining ? Colors.redAccent : Colors.white54;
    final icon = improving ? Icons.trending_up : declining ? Icons.trending_down : Icons.trending_flat;
    final label = improving
        ? 'Improving! +${trend.toStringAsFixed(1)} pts recently'
        : declining
            ? 'Room to grow — ${trend.toStringAsFixed(1)} pts recently'
            : gamesCount < 2
                ? 'Play more games to see your trend'
                : 'Holding steady';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: color, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _WinRateCard extends StatelessWidget {
  final int wins, losses, draws, total;
  const _WinRateCard({required this.wins, required this.losses, required this.draws, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Checkmate / Draw / Resigned',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (wins > 0)
                    Expanded(flex: wins, child: Container(color: Colors.greenAccent)),
                  if (draws > 0)
                    Expanded(flex: draws, child: Container(color: Colors.amber)),
                  if (losses > 0)
                    Expanded(flex: losses, child: Container(color: Colors.redAccent)),
                  if (total == 0)
                    Expanded(child: Container(color: Colors.white12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _WinLabel(color: Colors.greenAccent, label: '$wins ♚'),
              const SizedBox(width: 12),
              _WinLabel(color: Colors.amber, label: '$draws D'),
              const SizedBox(width: 12),
              _WinLabel(color: Colors.redAccent, label: '$losses R'),
              const Spacer(),
              if (total > 0)
                Text(
                  '${(wins / total * 100).toStringAsFixed(0)}% checkmates',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WinLabel extends StatelessWidget {
  final Color color;
  final String label;
  const _WinLabel({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _ScoreChart extends StatelessWidget {
  final List<GameRecord> games;
  const _ScoreChart({required this.games});

  @override
  Widget build(BuildContext context) {
    final display = games.length > 20 ? games.sublist(games.length - 20) : games;
    return Container(
      height: 120,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: CustomPaint(
        painter: _ChartPainter(scores: display.map((g) => g.performanceScore).toList()),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Text(
            'Last ${display.length} games',
            style: const TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<int> scores;
  const _ChartPainter({required this.scores});

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2) return;

    final linePaint = Paint()
      ..color = const Color(0xFFF4B942)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = const Color(0xFFF4B942)
      ..style = PaintingStyle.fill;

    final fillPaint = Paint()
      ..color = const Color(0xFFF4B942).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;

    for (final level in [40, 70]) {
      final y = size.height * (1 - level / 100);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }

    final xStep = size.width / (scores.length - 1);
    Offset toPoint(int i) => Offset(
          i * xStep,
          size.height * (1 - scores[i].clamp(0, 100) / 100),
        );

    final fillPath = Path();
    fillPath.moveTo(0, size.height);
    for (int i = 0; i < scores.length; i++) fillPath.lineTo(toPoint(i).dx, toPoint(i).dy);
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    final path = Path();
    path.moveTo(toPoint(0).dx, toPoint(0).dy);
    for (int i = 1; i < scores.length; i++) path.lineTo(toPoint(i).dx, toPoint(i).dy);
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < scores.length; i++) {
      canvas.drawCircle(toPoint(i), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.scores != scores;
}

// ── Achievements ──────────────────────────────────────────────────────────────

class _Achievement {
  final String icon;
  final String title;
  final String description;
  final bool unlocked;
  const _Achievement({
    required this.icon,
    required this.title,
    required this.description,
    required this.unlocked,
  });
}

List<_Achievement> _buildAchievements(List<GameRecord> games) {
  final totalGames = games.length;
  final wins = games.where((g) => g.result == GameStatus.checkmate).toList();
  final bestScore = totalGames > 0
      ? games.map((g) => g.performanceScore).reduce((a, b) => a > b ? a : b)
      : 0;
  final avgScore = totalGames > 0
      ? games.map((g) => g.performanceScore).reduce((a, b) => a + b) ~/ totalGames
      : 0;

  // Win streak from most recent
  int winStreak = 0;
  for (final g in games.reversed) {
    if (g.result == GameStatus.checkmate) {
      winStreak++;
    } else {
      break;
    }
  }

  // Max historical win streak
  int maxWinStreak = 0;
  int cur = 0;
  for (final g in games) {
    if (g.result == GameStatus.checkmate) {
      cur++;
      if (cur > maxWinStreak) maxWinStreak = cur;
    } else {
      cur = 0;
    }
  }

  // Play streak (consecutive days)
  final gameDays = games.map((g) {
    final d = g.playedAt;
    return DateTime(d.year, d.month, d.day);
  }).toSet();
  int playStreak = 0;
  var day = DateTime.now();
  day = DateTime(day.year, day.month, day.day);
  if (!gameDays.contains(day)) day = day.subtract(const Duration(days: 1));
  while (gameDays.contains(day)) {
    playStreak++;
    day = day.subtract(const Duration(days: 1));
  }

  final masterGames = games.where((g) => g.difficulty == 5).toList();

  return [
    _Achievement(
      icon: '♟',
      title: 'First Move',
      description: 'Play your first game',
      unlocked: totalGames >= 1,
    ),
    _Achievement(
      icon: '♚',
      title: 'First Checkmate',
      description: 'Win a game',
      unlocked: wins.isNotEmpty,
    ),
    _Achievement(
      icon: '📚',
      title: 'Getting Started',
      description: 'Play 10 games',
      unlocked: totalGames >= 10,
    ),
    _Achievement(
      icon: '🏆',
      title: 'Dedicated',
      description: 'Play 50 games',
      unlocked: totalGames >= 50,
    ),
    _Achievement(
      icon: '⭐',
      title: 'Sharp Mind',
      description: 'Score 80+ in a game',
      unlocked: bestScore >= 80,
    ),
    _Achievement(
      icon: '💎',
      title: 'Precision',
      description: 'Average score above 70',
      unlocked: avgScore >= 70,
    ),
    _Achievement(
      icon: '⚡',
      title: 'On a Roll',
      description: 'Win 3 games in a row',
      unlocked: maxWinStreak >= 3,
    ),
    _Achievement(
      icon: '🔥',
      title: 'Habit Builder',
      description: 'Play 3 days in a row',
      unlocked: playStreak >= 3,
    ),
    _Achievement(
      icon: '🎯',
      title: 'Master Challenge',
      description: 'Play at Master difficulty',
      unlocked: masterGames.isNotEmpty,
    ),
    _Achievement(
      icon: '👑',
      title: 'Master Slayer',
      description: 'Beat Master difficulty',
      unlocked: masterGames.any((g) => g.result == GameStatus.checkmate),
    ),
  ];
}

class _AchievementsCard extends StatelessWidget {
  final List<GameRecord> allGames;
  const _AchievementsCard({required this.allGames});

  @override
  Widget build(BuildContext context) {
    final achievements = _buildAchievements(allGames);
    final unlocked = achievements.where((a) => a.unlocked).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$unlocked / ${achievements.length} unlocked',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 80,
                  child: LinearProgressIndicator(
                    value: unlocked / achievements.length,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF4B942)),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: achievements.map((a) => _AchievementChip(achievement: a)).toList(),
          ),
        ],
      ),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  final _Achievement achievement;
  const _AchievementChip({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return Tooltip(
      message: achievement.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: unlocked
              ? const Color(0xFFF4B942).withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: unlocked
                ? const Color(0xFFF4B942).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              achievement.icon,
              style: TextStyle(
                fontSize: 14,
                color: unlocked ? null : null,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              achievement.title,
              style: TextStyle(
                color: unlocked ? const Color(0xFFF4B942) : Colors.white24,
                fontSize: 12,
                fontWeight: unlocked ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Difficulty breakdown ───────────────────────────────────────────────────────

class _DifficultyBreakdown extends StatelessWidget {
  final List<GameRecord> games;
  const _DifficultyBreakdown({required this.games});

  static const _labels = {1: 'Novice', 2: 'Beginner', 3: 'Casual', 4: 'Club', 5: 'Master'};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        children: List.generate(5, (i) {
          final d = i + 1;
          final dGames = games.where((g) => g.difficulty == d).toList();
          if (dGames.isEmpty) return const SizedBox.shrink();
          final avg = dGames.map((g) => g.performanceScore).reduce((a, b) => a + b) ~/ dGames.length;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(_labels[d]!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: avg / 100,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        avg >= 70 ? Colors.greenAccent : avg >= 40 ? const Color(0xFFF4B942) : Colors.redAccent,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text('$avg', style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.right),
                ),
                const SizedBox(width: 4),
                Text('(${dGames.length})', style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Recent game row ────────────────────────────────────────────────────────────

class _RecentGameRow extends StatelessWidget {
  final GameRecord record;
  const _RecentGameRow({required this.record});

  String get _resultLabel {
    switch (record.result) {
      case GameStatus.checkmate: return 'Checkmate';
      case GameStatus.stalemate: return 'Stalemate';
      case GameStatus.draw: return 'Draw';
      case GameStatus.resigned: return 'Resigned';
      default: return record.result.name;
    }
  }

  Color get _resultColor {
    if (record.result == GameStatus.checkmate) return Colors.greenAccent;
    if (record.result == GameStatus.resigned) return Colors.redAccent;
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final score = record.performanceScore;
    final scoreColor = score >= 70 ? Colors.greenAccent : score >= 40 ? const Color(0xFFF4B942) : Colors.redAccent;
    final diff = record.difficulty;
    final diffLabel = {1: 'Novice', 2: 'Beginner', 3: 'Casual', 4: 'Club', 5: 'Master'}[diff] ?? 'Lv$diff';
    final ago = _timeAgo(record.playedAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.white10,
                  color: scoreColor,
                  strokeWidth: 4,
                ),
                Text('$score', style: TextStyle(color: scoreColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_resultLabel, style: TextStyle(color: _resultColor, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Text('· $diffLabel', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${record.playerColor.name} · $ago',
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
