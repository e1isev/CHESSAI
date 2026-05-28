import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../services/game_analyzer.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<GameRecord>> _future;
  final _analyzer = GameAnalyzer();

  @override
  void initState() {
    super.initState();
    _future = _analyzer.loadGames();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        title: const Text('Game History'),
      ),
      body: FutureBuilder<List<GameRecord>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFF4B942)),
            );
          }
          final games = snap.data ?? [];
          if (games.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, color: Colors.white24, size: 64),
                  SizedBox(height: 12),
                  Text(
                    'No games yet',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Play a game to see your history here',
                    style: TextStyle(color: Colors.white24, fontSize: 13),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _GameTile(
              record: games[i],
              onDelete: () async {
                await _analyzer.deleteGame(games[i].id!);
                setState(() => _future = _analyzer.loadGames());
              },
            ),
          );
        },
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final GameRecord record;
  final VoidCallback onDelete;

  const _GameTile({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final score = record.performanceScore;
    final scoreColor = score >= 70
        ? Colors.greenAccent
        : score >= 40
            ? const Color(0xFFF4B942)
            : Colors.redAccent;

    String resultText;
    switch (record.result) {
      case GameStatus.checkmate:
        resultText = 'Checkmate';
      case GameStatus.draw:
        resultText = 'Draw';
      case GameStatus.resigned:
        resultText = 'Resigned';
      default:
        resultText = 'Incomplete';
    }

    const diffLabels = {1: 'Novice', 2: 'Beginner', 3: 'Casual', 4: 'Club', 5: 'Master'};

    return Dismissible(
      key: Key('game_${record.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2137),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1E3A5F)),
        ),
        child: Row(
          children: [
            // Score ring
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    backgroundColor: Colors.white12,
                    color: scoreColor,
                    strokeWidth: 4,
                  ),
                  Text(
                    '$score',
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
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
                      Text(
                        resultText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: record.playerColor == PlayerColor.white ? 'White' : 'Black',
                        color: record.playerColor == PlayerColor.white
                            ? Colors.white
                            : Colors.black87,
                        bg: record.playerColor == PlayerColor.white
                            ? Colors.white24
                            : Colors.white12,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${diffLabels[record.difficulty] ?? 'Level ${record.difficulty}'} · '
                    '${_formatDate(record.playedAt)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _Chip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
