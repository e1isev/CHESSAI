import 'package:chess/chess.dart' as chess_lib;
import '../models/game_state.dart';
import 'gemini_coaching_service.dart';

/// Rule-based coaching using chess.dart position analysis and Stockfish centipawn data.
/// No network calls — works entirely on-device.
class LocalCoachingService {
  static const _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
  static const _ranks = ['1', '2', '3', '4', '5', '6', '7', '8'];

  // ── In-game: mid-game tip ─────────────────────────────────────────────────

  Future<String?> getMidGameTip({
    required String fen,
    required String lastMove,
    required List<String> moveHistory,
    PlayerColor playerColor = PlayerColor.white,
  }) async {
    final chess = chess_lib.Chess();
    chess.load(fen);
    final moveNum = moveHistory.length;
    if (moveNum <= 12) return _openingTip(chess, playerColor, moveNum);
    return _middlegameTip(chess, lastMove, moveNum);
  }

  // ── In-game: AI move explanation ──────────────────────────────────────────

  Future<String?> getAiMoveExplanation({
    required String move,
    required String fen,
    required List<String> moveHistory,
  }) async {
    return _explainMove(move);
  }

  // ── In-game: blunder warning ──────────────────────────────────────────────

  Future<String?> getBlunderWarning({
    required String proposedMove,
    required String fen,
    required int evalBefore,
    required int evalAfter,
  }) async {
    final drop = evalBefore - evalAfter;
    if (drop < 150) return null;
    final pawns = (drop / 100).toStringAsFixed(1);
    final label = drop >= 300 ? 'blunder' : 'mistake';
    const templates = [
      'Watch out — that move might be a {l}, losing ~{p} pawns of advantage. Look again!',
      'Before playing {m}, double-check: you may be giving up ~{p} pawns.',
      'That could be a {l}! You\'d lose about {p} pawns — is there something better?',
    ];
    final t = templates[drop.abs() % templates.length];
    return t
        .replaceAll('{m}', proposedMove)
        .replaceAll('{l}', label)
        .replaceAll('{p}', pawns);
  }

  // ── Post-game analysis ────────────────────────────────────────────────────

  Future<PostGameAnalysis?> analyzeGame({
    required String pgn,
    required List<String> moveHistory,
  }) async {
    if (moveHistory.isEmpty) return null;

    final chess = chess_lib.Chess();
    final mistakes = <MistakeEntry>[];
    BestMoveEntry? bestMove;
    var bestGain = 0;

    for (final san in moveHistory) {
      final before = _materialBalance(chess);
      try {
        chess.move(san);
      } catch (_) {
        break;
      }
      final after = _materialBalance(chess);
      final swing = after - before;

      if (swing <= -150 && mistakes.length < 3) {
        final pawns = (swing.abs() / 100).toStringAsFixed(1);
        mistakes.add(MistakeEntry(
          move: san,
          comment: 'This move lost about $pawns pawns of material — the position became significantly harder after this.',
          better: 'Before capturing or moving here, check if your piece is defended and whether your opponent gets something back.',
        ));
      }

      if (swing >= 150 && swing > bestGain) {
        bestGain = swing;
        bestMove = BestMoveEntry(
          move: san,
          comment: 'This move won about ${(swing / 100).toStringAsFixed(1)} pawns of material — great tactical alertness!',
        );
      }
    }

    // Score: 70 baseline, -10 per mistake, +5 if a best move was found
    var score = 70 - (mistakes.length * 10) + (bestMove != null ? 5 : 0);
    // Reward longer games slightly (more moves = more practice)
    score += (moveHistory.length / 8).clamp(0, 10).toInt();
    score = score.clamp(10, 95);

    return PostGameAnalysis(
      score: score,
      summary: _buildSummary(moveHistory.length, score),
      mistakes: mistakes,
      bestMove: bestMove,
      advice: _buildAdvice(mistakes, moveHistory.length),
    );
  }

  // ── Tip generators ────────────────────────────────────────────────────────

  String _openingTip(chess_lib.Chess chess, PlayerColor playerColor, int moveNum) {
    final isWhite = playerColor == PlayerColor.white;
    final undeveloped = isWhite
        ? _undevelopedCount(chess, chess_lib.Color.WHITE, ['b1', 'g1', 'c1', 'f1'])
        : _undevelopedCount(chess, chess_lib.Color.BLACK, ['b8', 'g8', 'c8', 'f8']);
    final kingStart = isWhite ? 'e1' : 'e8';
    final notCastled = _findKing(chess, isWhite ? chess_lib.Color.WHITE : chess_lib.Color.BLACK) == kingStart;

    if (moveNum <= 4) {
      final centerPawns = _centerPawns(chess, isWhite ? chess_lib.Color.WHITE : chess_lib.Color.BLACK);
      if (centerPawns == 0) {
        return 'Opening tip: fight for the center! A pawn on e4 or d4 gives your pieces room to develop and controls important squares.';
      }
    }

    if (undeveloped >= 3 && moveNum >= 4) {
      return 'Your knights and bishops are still on their starting squares. Try to develop them before moving the same piece twice or pushing more pawns.';
    }

    if (notCastled && undeveloped <= 1 && moveNum >= 6) {
      return 'Your pieces look well developed! Now is a great time to castle and move your king to safety — it also connects your rooks.';
    }

    const tips = [
      'Good opening! Remember: each early move should develop a piece, control the center, or improve your king safety.',
      'Avoid moving the same piece twice in the opening unless you win material or are forced to. Time matters early on.',
      'Your position is developing nicely. Think about which piece is least active and find a good square for it.',
      'Look at the center — whoever controls e4, e5, d4, d5 usually has more space to maneuver.',
    ];
    return tips[moveNum % tips.length];
  }

  String _middlegameTip(chess_lib.Chess chess, String lastMove, int moveNum) {
    if (_isEndgame(chess)) {
      return 'You\'ve entered the endgame! Activate your king — it becomes a powerful fighting piece once queens are off the board.';
    }

    final balance = _materialBalance(chess);
    if (lastMove.contains('x') && balance.abs() >= 200) {
      final side = balance > 0 ? 'ahead' : 'behind';
      final diff = (balance.abs() / 100).toStringAsFixed(1);
      return balance > 0
          ? 'After that exchange, you\'re $side by ~$diff pawns. Look to simplify into a winning endgame!'
          : 'After that exchange, you\'re $side by ~$diff pawns. Look for active counterplay or tactics to fight back.';
    }

    const tips = [
      'Before each move, ask: "What is my opponent threatening?" Stopping threats can be more valuable than making your own.',
      'Look for the least active piece on the board and find a better square for it — piece activity often decides middlegame battles.',
      'Tactical patterns to spot: forks (attacking two pieces at once), pins (piece can\'t move), and skewers (like a reverse pin).',
      'Avoid moving pawns in front of your king without a good reason — pawn breaks near your king create weaknesses.',
      'A good rule: before a big plan, do a quick one-move check — can your opponent take something for free?',
    ];
    return tips[moveNum % tips.length];
  }

  // ── Move explanation ──────────────────────────────────────────────────────

  String _explainMove(String san) {
    if (san == 'O-O') return 'I castled kingside — moving my king to safety behind the pawns and connecting my rooks.';
    if (san == 'O-O-O') return 'I castled queenside — securing my king and activating the queenside rook.';
    if (san.contains('#')) return 'That\'s checkmate — well played for fighting to the end!';
    if (san.contains('+')) {
      return 'I played $san to give check, forcing you to respond immediately and limiting your options this turn.';
    }
    if (san.contains('x')) {
      if (san[0] == san[0].toLowerCase()) {
        return 'My pawn captured on ${_stripDecorations(san)} — winning material while opening the file for my rooks.';
      }
      final name = _pieceName(san[0]);
      return 'I captured with my $name ($san) — exchanging pieces can gain material or simplify into a better endgame.';
    }
    if (san.contains('=')) {
      return 'Pawn promotion! My pawn reached the back rank and became a queen — the most powerful piece on the board.';
    }
    if (san[0] == san[0].toLowerCase()) {
      return 'I advanced my pawn to ${_stripDecorations(san)} — claiming space and restricting your piece mobility.';
    }
    final name = _pieceName(san[0]);
    return 'I moved my $name to ${_stripDecorations(san)} — improving its activity and putting pressure on your position.';
  }

  // ── Summary and advice ────────────────────────────────────────────────────

  String _buildSummary(int moveCount, int score) {
    final length = moveCount <= 20 ? 'quick' : moveCount <= 40 ? 'solid' : 'long';
    if (score >= 65) {
      return 'Great $length game of $moveCount moves! You kept good material balance and showed strong positional play. Keep building on this!';
    } else if (score >= 45) {
      return 'Decent $length game — the position stayed balanced for a good portion, and you had some nice moments. Review the key mistakes below to level up.';
    }
    return 'Tough $length game of $moveCount moves. Every game is a lesson — the mistakes below are your best training material. Keep going!';
  }

  String _buildAdvice(List<MistakeEntry> mistakes, int moveCount) {
    if (mistakes.isEmpty) {
      return 'No major material swings — excellent game! Work on converting small advantages cleanly in future games.';
    }
    if (moveCount <= 20) {
      return 'Focus on the opening: develop all minor pieces before attacking, control the center, and castle before move 10 when possible.';
    }
    return 'Study the positions before your biggest mistakes — ask "what does my opponent get back?" before every capture.';
  }

  // ── Board helpers ─────────────────────────────────────────────────────────

  int _materialBalance(chess_lib.Chess chess) {
    const values = {
      chess_lib.PieceType.PAWN: 100,
      chess_lib.PieceType.KNIGHT: 300,
      chess_lib.PieceType.BISHOP: 325,
      chess_lib.PieceType.ROOK: 500,
      chess_lib.PieceType.QUEEN: 900,
    };
    var bal = 0;
    for (final f in _files) {
      for (final r in _ranks) {
        final p = chess.get('$f$r');
        if (p == null || p.type == chess_lib.PieceType.KING) continue;
        final v = values[p.type] ?? 0;
        bal += p.color == chess_lib.Color.WHITE ? v : -v;
      }
    }
    return bal;
  }

  int _undevelopedCount(chess_lib.Chess chess, chess_lib.Color color, List<String> startSquares) {
    var count = 0;
    for (final sq in startSquares) {
      final p = chess.get(sq);
      if (p != null && p.color == color &&
          (p.type == chess_lib.PieceType.KNIGHT || p.type == chess_lib.PieceType.BISHOP)) {
        count++;
      }
    }
    return count;
  }

  int _centerPawns(chess_lib.Chess chess, chess_lib.Color color) {
    var count = 0;
    for (final sq in ['e4', 'e5', 'd4', 'd5']) {
      final p = chess.get(sq);
      if (p?.type == chess_lib.PieceType.PAWN && p?.color == color) count++;
    }
    return count;
  }

  String? _findKing(chess_lib.Chess chess, chess_lib.Color color) {
    for (final f in _files) {
      for (final r in _ranks) {
        final p = chess.get('$f$r');
        if (p?.type == chess_lib.PieceType.KING && p?.color == color) return '$f$r';
      }
    }
    return null;
  }

  bool _isEndgame(chess_lib.Chess chess) {
    var queens = 0, minors = 0;
    for (final f in _files) {
      for (final r in _ranks) {
        final p = chess.get('$f$r');
        if (p == null) continue;
        if (p.type == chess_lib.PieceType.QUEEN) queens++;
        if (p.type == chess_lib.PieceType.KNIGHT || p.type == chess_lib.PieceType.BISHOP) minors++;
      }
    }
    return queens == 0 || (queens <= 1 && minors <= 2);
  }

  String _pieceName(String letter) {
    const names = {'N': 'knight', 'B': 'bishop', 'R': 'rook', 'Q': 'queen', 'K': 'king'};
    return names[letter] ?? 'piece';
  }

  String _stripDecorations(String san) => san.replaceAll(RegExp(r'[x+=+#!?]'), '');
}
