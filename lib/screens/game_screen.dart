import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess_lib;

import '../models/game_state.dart';
import '../services/stockfish_service.dart';
import '../services/claude_coaching_service.dart';
import '../services/opening_detector.dart';
import '../widgets/chess_board.dart';
import '../widgets/coaching_panel.dart';
import '../widgets/opening_banner.dart';
import '../widgets/move_list.dart';
import 'analysis_screen.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final stockfishServiceProvider = Provider<StockfishService>((ref) {
  final s = StockfishService();
  ref.onDispose(s.dispose);
  return s;
});

final claudeServiceProvider = Provider<ClaudeCoachingService?>((ref) {
  final key = ref.watch(apiKeyProvider);
  if (key == null || key.isEmpty) return null;
  return ClaudeCoachingService(apiKey: key);
});

final apiKeyProvider = StateProvider<String?>((ref) => null);

final openingDetectorProvider = Provider<OpeningDetector>((ref) => OpeningDetector());

// ---------------------------------------------------------------------------
// Game Notifier
// ---------------------------------------------------------------------------

final gameNotifierProvider =
    StateNotifierProvider<GameNotifier, GameState>((ref) {
  return GameNotifier(
    stockfish: ref.watch(stockfishServiceProvider),
    claudeService: ref.watch(claudeServiceProvider),
    openingDetector: ref.watch(openingDetectorProvider),
  );
});

class GameNotifier extends StateNotifier<GameState> {
  final StockfishService _stockfish;
  final ClaudeCoachingService? _claude;
  final OpeningDetector _openingDetector;
  chess_lib.Chess _chess = chess_lib.Chess();
  bool _stockfishReady = false;

  GameNotifier({
    required StockfishService stockfish,
    required ClaudeCoachingService? claudeService,
    required OpeningDetector openingDetector,
  })  : _stockfish = stockfish,
        _claude = claudeService,
        _openingDetector = openingDetector,
        super(GameState.initial);

  Future<void> startGame({
    required PlayerColor playerColor,
    required int difficulty,
  }) async {
    _chess = chess_lib.Chess();
    _openingDetector.reset();
    state = GameState(
      fen: _chess.fen,
      playerColor: playerColor,
      difficulty: difficulty,
      status: GameStatus.playing,
    );

    if (!_stockfishReady) {
      try {
        await _stockfish.init();
        _stockfishReady = true;
      } catch (_) {
        _stockfishReady = false;
      }
    }

    // If AI plays white, make its first move
    if (playerColor == PlayerColor.black) {
      await _makeAiMove();
    }
  }

  void selectSquare(String square) {
    if (state.status != GameStatus.playing) return;
    final isPlayerTurn = _isPlayerTurn();
    if (!isPlayerTurn) return;

    final selected = state.selectedSquare;

    // If we already have a selected piece and tap a valid move target
    if (selected != null && state.validMoveSquares.contains(square)) {
      _attemptMove(selected, square);
      return;
    }

    // Select new square if it has a player piece
    final piece = _chess.get(square);
    if (piece == null) {
      state = state.copyWith(clearSelectedSquare: true, validMoveSquares: []);
      return;
    }

    final isWhitePiece = piece.color == chess_lib.Color.WHITE;
    final playerIsWhite = state.playerColor == PlayerColor.white;
    if (isWhitePiece != playerIsWhite) {
      state = state.copyWith(clearSelectedSquare: true, validMoveSquares: []);
      return;
    }

    final moves = _chess.generate_moves().where((m) => m.fromAlgebraic == square).map((m) => m.toAlgebraic).toList();
    state = state.copyWith(selectedSquare: square, validMoveSquares: moves);
  }

  Future<void> _attemptMove(String from, String to) async {
    // Check for promotion
    final piece = _chess.get(from);
    String? promotion;
    if (piece?.type == chess_lib.PieceType.PAWN) {
      final rank = to[1];
      if ((state.playerColor == PlayerColor.white && rank == '8') ||
          (state.playerColor == PlayerColor.black && rank == '1')) {
        promotion = await _showPromotionDialog();
      }
    }

    final success = _chess.move({
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
    });

    if (success == false || success == null) {
      state = state.copyWith(clearSelectedSquare: true, validMoveSquares: []);
      return;
    }

    final history = _chess.history as List;
    final san = history.isNotEmpty ? history.last.toString() : '$from$to';
    final newMoves = <String>[...state.sanMoves, san];
    final opening = _openingDetector.update(newMoves);

    state = state.copyWith(
      fen: _chess.fen,
      sanMoves: newMoves,
      currentOpening: opening,
      clearSelectedSquare: true,
      validMoveSquares: [],
      lastMoveFrom: from,
      lastMoveTo: to,
      clearAiExplanation: true,
      clearBlunderWarning: true,
      isLoadingCoaching: _claude != null,
    );

    if (_chess.in_checkmate) {
      state = state.copyWith(status: GameStatus.checkmate);
      _onGameOver();
      return;
    }
    if (_chess.in_stalemate || _chess.in_draw) {
      state = state.copyWith(status: GameStatus.draw);
      _onGameOver();
      return;
    }

    // Fetch coaching tip in background
    _fetchCoachingTip(san);

    // AI responds
    await _makeAiMove();
  }

  Future<void> _makeAiMove() async {
    if (!_isAiTurn()) return;

    state = state.copyWith(isAiThinking: true, clearAiExplanation: true);

    String? uciMove;
    try {
      if (_stockfishReady) {
        uciMove = await _stockfish.getBestMove(
          fen: _chess.fen,
          difficulty: state.difficulty,
          thinkTimeMs: 1000 + state.difficulty * 200,
        );
      }
    } catch (_) {
      uciMove = null;
    }

    // Fallback: pick a random legal move
    if (uciMove == null || uciMove == '(none)') {
      final moves = _chess.generate_moves();
      if (moves.isEmpty) return;
      moves.shuffle();
      final m = moves.first;
      uciMove = '${m.fromAlgebraic}${m.toAlgebraic}';
    }

    final from = uciMove.substring(0, 2);
    final to = uciMove.substring(2, 4);
    final promo = uciMove.length == 5 ? uciMove[4] : null;

    _chess.move({
      'from': from,
      'to': to,
      if (promo != null) 'promotion': promo,
    });

    final history = _chess.history as List;
    final san = history.isNotEmpty ? history.last.toString() : uciMove;
    final newMoves = <String>[...state.sanMoves, san];
    final opening = _openingDetector.update(newMoves);

    state = state.copyWith(
      fen: _chess.fen,
      sanMoves: newMoves,
      currentOpening: opening,
      isAiThinking: false,
      lastMoveFrom: from,
      lastMoveTo: to,
    );

    if (_chess.in_checkmate) {
      state = state.copyWith(status: GameStatus.checkmate);
      _onGameOver();
      return;
    }
    if (_chess.in_stalemate || _chess.in_draw) {
      state = state.copyWith(status: GameStatus.draw);
      _onGameOver();
      return;
    }

    // Get AI move explanation from Claude
    _fetchAiExplanation(san);
  }

  Future<void> _fetchCoachingTip(String lastMove) async {
    if (_claude == null) {
      state = state.copyWith(isLoadingCoaching: false);
      return;
    }
    final tip = await _claude!.getMidGameTip(
      fen: state.fen,
      lastMove: lastMove,
      moveHistory: state.sanMoves,
    );
    state = state.copyWith(
      lastCoachingTip: tip,
      isLoadingCoaching: false,
    );
  }

  Future<void> _fetchAiExplanation(String move) async {
    if (_claude == null) return;
    final explanation = await _claude!.getAiMoveExplanation(
      move: move,
      fen: state.fen,
      moveHistory: state.sanMoves,
    );
    if (mounted) {
      state = state.copyWith(aiMoveExplanation: explanation);
    }
  }

  Future<String?> _showPromotionDialog() async => 'q'; // Always promote to queen for simplicity

  void resign() {
    if (state.status != GameStatus.playing) return;
    state = state.copyWith(status: GameStatus.resigned);
    _onGameOver();
  }

  void _onGameOver() {
    // Navigation handled in UI
  }

  bool _isPlayerTurn() {
    final isWhiteTurn = _chess.turn == chess_lib.Color.WHITE;
    return state.playerColor == PlayerColor.white
        ? isWhiteTurn
        : !isWhiteTurn;
  }

  bool _isAiTurn() => !_isPlayerTurn() && state.status == GameStatus.playing;

  String get pgn => state.sanMoves.asMap().entries.map((e) {
        final idx = e.key;
        final move = e.value;
        if (idx % 2 == 0) return '${idx ~/ 2 + 1}. $move';
        return move;
      }).join(' ');
}

// ---------------------------------------------------------------------------
// Game Screen UI
// ---------------------------------------------------------------------------

class GameScreen extends ConsumerWidget {
  final PlayerColor playerColor;
  final int difficulty;

  const GameScreen({
    super.key,
    required this.playerColor,
    required this.difficulty,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(gameNotifierProvider);
    final notifier = ref.read(gameNotifierProvider.notifier);

    // Start game on first build
    ref.listen<GameState>(gameNotifierProvider, (prev, next) {
      if (next.status == GameStatus.checkmate ||
          next.status == GameStatus.draw ||
          next.status == GameStatus.resigned) {
        // Navigate to analysis after a short delay
        Future.delayed(const Duration(milliseconds: 800), () {
          if (context.mounted) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AnalysisScreen(
                gameState: next,
                pgn: notifier.pgn,
              ),
            ));
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.psychology, color: Color(0xFFF4B942), size: 20),
            const SizedBox(width: 8),
            const Text('Chess Coach', style: TextStyle(fontSize: 16)),
            const Spacer(),
            _DifficultyBadge(difficulty: gs.difficulty),
          ],
        ),
        actions: [
          if (gs.status == GameStatus.playing)
            TextButton(
              onPressed: () => _confirmResign(context, notifier),
              child: const Text('Resign', style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status bar
            _StatusBar(gameState: gs),

            // Opening banner
            OpeningBanner(opening: gs.currentOpening),

            // Board
            Padding(
              padding: const EdgeInsets.all(8),
              child: ChessBoard(
                gameState: gs,
                onSquareTap: notifier.selectSquare,
              ),
            ),

            // Move list
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: MoveList(
                moves: gs.sanMoves,
                highlightedIndex: gs.sanMoves.isEmpty ? null : gs.sanMoves.length - 1,
              ),
            ),

            // Coaching panel
            CoachingPanel(gameState: gs),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResign(BuildContext context, GameNotifier notifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D2137),
        title: const Text('Resign?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to resign this game?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resign', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) notifier.resign();
  }
}

class _StatusBar extends StatelessWidget {
  final GameState gameState;

  const _StatusBar({required this.gameState});

  @override
  Widget build(BuildContext context) {
    String message;
    Color color;

    switch (gameState.status) {
      case GameStatus.checkmate:
        message = '♚ Checkmate!';
        color = const Color(0xFFF4B942);
      case GameStatus.draw:
        message = '½–½ Draw';
        color = Colors.white70;
      case GameStatus.resigned:
        message = 'Game resigned';
        color = Colors.redAccent;
      case GameStatus.playing:
        if (gameState.isAiThinking) {
          message = 'AI is thinking...';
          color = const Color(0xFF64B5F6);
        } else {
          final turnColor = gameState.fen.split(' ')[1] == 'w' ? 'White' : 'Black';
          final isYourTurn = (turnColor == 'White' && gameState.playerColor == PlayerColor.white) ||
              (turnColor == 'Black' && gameState.playerColor == PlayerColor.black);
          message = isYourTurn ? 'Your turn ($turnColor)' : '$turnColor to move';
          color = isYourTurn ? const Color(0xFFF4B942) : Colors.white54;
        }
      default:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        message,
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final int difficulty;

  const _DifficultyBadge({required this.difficulty});

  static const labels = {1: 'Novice', 2: 'Beginner', 3: 'Casual', 4: 'Club', 5: 'Master'};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF4B942).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF4B942).withValues(alpha: 0.3)),
      ),
      child: Text(
        labels[difficulty] ?? 'Level $difficulty',
        style: const TextStyle(
          color: Color(0xFFF4B942),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
