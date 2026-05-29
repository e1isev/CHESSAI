import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../services/game_analyzer.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<GameRecord> _games = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final games = await GameAnalyzer().loadGames(limit: 100);
    if (mounted) setState(() { _games = games.reversed.toList(); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        title: const Text('My Progress'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF4B942)))
          : _games.isEmpty
              ? _EmptyState()
              : _ProgressBody(games: _games),
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
  const _ProgressBody({required this.games});

  int get _wins => games.where((g) => g.result == GameStatus.checkmate).length;

  int get _losses => games.where((g) => g.result == GameStatus.resigned).length;

  int get _draws => games.where((g) =>
      g.result == GameStatus.stalemate || g.result == GameStatus.draw).length;

  int get _avgScore {
    if (games.isEmpty) return 0;
    return games.map((g) => g.performanceScore).reduce((a, b) => a + b) ~/ games.length;
  }

  int get _bestScore => games.map((g) => g.performanceScore).reduce((a, b) => a > b ? a : b);

  // last 10 games trend
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

  @override
  Widget build(BuildContext context) {
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

          const SizedBox(height: 14),

          // Trend indicator
          _TrendCard(trend: _recentTrend, gamesCount: games.length),

          const SizedBox(height: 14),

          // Win/Loss/Draw
          _WinRateCard(wins: _wins, losses: _losses, draws: _draws, total: games.length),

          const SizedBox(height: 14),

          // Score chart
          _SectionHeader(title: 'Performance Over Time'),
          const SizedBox(height: 8),
          _ScoreChart(games: games),

          const SizedBox(height: 14),

          // Difficulty breakdown
          _SectionHeader(title: 'Difficulty Breakdown'),
          const SizedBox(height: 8),
          _DifficultyBreakdown(games: games),

          const SizedBox(height: 14),

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
          // Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (wins > 0)
                    Expanded(
                      flex: wins,
                      child: Container(color: Colors.greenAccent),
                    ),
                  if (draws > 0)
                    Expanded(
                      flex: draws,
                      child: Container(color: Colors.amber),
                    ),
                  if (losses > 0)
                    Expanded(
                      flex: losses,
                      child: Container(color: Colors.redAccent),
                    ),
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

    // Guideline at 70 and 40
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

    // Fill area
    final fillPath = Path();
    fillPath.moveTo(0, size.height);
    for (int i = 0; i < scores.length; i++) fillPath.lineTo(toPoint(i).dx, toPoint(i).dy);
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Line
    final path = Path();
    path.moveTo(toPoint(0).dx, toPoint(0).dy);
    for (int i = 1; i < scores.length; i++) path.lineTo(toPoint(i).dx, toPoint(i).dy);
    canvas.drawPath(path, linePaint);

    // Dots
    for (int i = 0; i < scores.length; i++) {
      canvas.drawCircle(toPoint(i), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.scores != scores;
}

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
          // Score ring
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
