import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_state.dart';
import '../services/gemini_coaching_service.dart';
import '../services/game_analyzer.dart';
import '../widgets/chess_board.dart';
import '../widgets/move_list.dart';
import 'game_screen.dart';
import 'home_screen.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final GameState gameState;
  final String pgn;

  const AnalysisScreen({super.key, required this.gameState, required this.pgn});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  PostGameAnalysis? _analysis;
  bool _loading = true;
  int _replayIndex = -1;
  late List<String> _fenHistory;

  @override
  void initState() {
    super.initState();
    _buildFenHistory();
    _runAnalysis();
  }

  void _buildFenHistory() {
    _fenHistory = [GameState.initial.fen];
    // We don't replay FENs without chess engine here; just store move list for display
  }

  Future<void> _runAnalysis() async {
    final claude = ref.read(geminiServiceProvider);
    if (claude != null && widget.pgn.isNotEmpty) {
      final result = await claude.analyzeGame(
        pgn: widget.pgn,
        moveHistory: widget.gameState.sanMoves,
      );
      if (mounted) {
        setState(() {
          _analysis = result;
          _loading = false;
        });
      }

      // Save game
      final score = result?.score ?? GameAnalyzer.computeScore([], widget.gameState.sanMoves.length);
      final record = GameRecord(
        pgn: widget.pgn,
        fen: widget.gameState.fen,
        playedAt: DateTime.now(),
        difficulty: widget.gameState.difficulty,
        result: widget.gameState.status,
        playerColor: widget.gameState.playerColor,
        performanceScore: score,
        annotations: [],
      );
      await GameAnalyzer().saveGame(record);
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = widget.gameState;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        title: const Text('Game Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (_) => false,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Score card
              if (_analysis != null) _ScoreCard(analysis: _analysis!),
              if (_loading) const _LoadingCard(),

              const SizedBox(height: 12),

              // Final board position
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1E3A5F)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ChessBoard(
                    gameState: gs,
                    onSquareTap: (_) {},
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Move list
              const Text(
                'Move List',
                style: TextStyle(color: Color(0xFFF4B942), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2137),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MoveList(moves: gs.sanMoves),
              ),

              const SizedBox(height: 12),

              // Analysis details
              if (_analysis != null) ...[
                _SectionTitle(title: 'Summary'),
                _AnalysisCard(
                  child: Text(
                    _analysis!.summary,
                    style: const TextStyle(color: Colors.white70, height: 1.5),
                  ),
                ),

                if (_analysis!.mistakes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SectionTitle(title: 'Top Mistakes'),
                  ..._analysis!.mistakes.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MistakeCard(mistake: m),
                      )),
                ],

                if (_analysis!.bestMove != null) ...[
                  const SizedBox(height: 8),
                  _SectionTitle(title: 'Best Move'),
                  _AnalysisCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            _analysis!.bestMove!.move,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _analysis!.bestMove!.comment,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_analysis!.advice.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SectionTitle(title: 'Key Advice'),
                  _AnalysisCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Color(0xFFF4B942), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _analysis!.advice,
                            style: const TextStyle(color: Colors.white70, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 20),

              // Play again button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (_) => false,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Play Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4B942),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final PostGameAnalysis analysis;

  const _ScoreCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final score = analysis.score;
    final color = score >= 70
        ? Colors.greenAccent
        : score >= 40
            ? const Color(0xFFF4B942)
            : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.white12,
                  color: color,
                  strokeWidth: 6,
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score >= 70
                      ? 'Great game!'
                      : score >= 40
                          ? 'Decent effort!'
                          : 'Keep practicing!',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Performance score: $score / 100',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4B942)),
            ),
          ),
          SizedBox(width: 12),
          Text('Analyzing your game...', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFF4B942),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final Widget child;

  const _AnalysisCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: child,
    );
  }
}

class _MistakeCard extends StatelessWidget {
  final MistakeEntry mistake;

  const _MistakeCard({required this.mistake});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0D0D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.close, color: Colors.redAccent, size: 16),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  mistake.move,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(mistake.comment, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (mistake.better.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '✓ Better: ${mistake.better}',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
