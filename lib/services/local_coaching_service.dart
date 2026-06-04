import 'package:chess/chess.dart' as chess_lib;
import '../data/openings_library.dart';
import '../models/game_state.dart';
import 'gemini_coaching_service.dart';
import 'tactics_detector.dart';

/// Fully offline coaching using chess.dart position analysis,
/// geometric tactics detection, and opening-library knowledge.
/// No network calls, no API tokens.
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
    final color = _chessColor(playerColor);

    // ── Tactical alerts (highest priority) ───────────────────────────────
    // After player moves it's opponent's turn, so warn about opponent threats.
    final hanging = TacticsDetector.hangingPiece(chess, color);
    if (hanging != null) {
      final name = TacticsDetector.pieceName(hanging.piece);
      final pawns = (hanging.gain / 100).toStringAsFixed(1);
      return hanging.gain >= 300
          ? 'Danger: your $name on ${hanging.square} is hanging and can be won for ~$pawns pawns! Move it or defend it before it\'s too late.'
          : 'Watch out — your $name on ${hanging.square} might be captured for a ~$pawns-pawn swing. Make sure it\'s properly defended.';
    }

    // ── Opening phase ─────────────────────────────────────────────────────
    if (moveNum <= 14) {
      return _openingTip(chess, color, moveHistory, moveNum, lastMove);
    }

    // ── Fork hints ────────────────────────────────────────────────────────
    final fork = TacticsDetector.knightFork(chess, color)
        ?? TacticsDetector.pawnFork(chess, color);
    if (fork != null) {
      final name = TacticsDetector.pieceName(fork.piece);
      return 'Tactical opportunity: look at advancing your $name to ${fork.square} — it would attack two opponent pieces at once. That\'s a fork!';
    }

    // ── Middlegame / endgame ───────────────────────────────────────────────
    return _middlegameTip(chess, lastMove, moveNum);
  }

  // ── In-game: AI move explanation ──────────────────────────────────────────

  Future<String?> getAiMoveExplanation({
    required String move,
    required String fen,
    required List<String> moveHistory,
    PlayerColor playerColor = PlayerColor.white,
  }) async {
    final base = _explainMove(move);

    // After AI moves it's the player's turn — hint at immediate opportunities.
    final chess = chess_lib.Chess();
    chess.load(fen);
    final color = _chessColor(playerColor);

    final capture = TacticsDetector.bestCapture(chess, color);
    if (capture != null && capture.gain >= 200) {
      final name = TacticsDetector.pieceName(capture.piece);
      final pawns = (capture.gain / 100).toStringAsFixed(1);
      return '$base Now look carefully — you can win a $name on ${capture.square} for about $pawns pawns!';
    }

    final fork = TacticsDetector.knightFork(chess, color)
        ?? TacticsDetector.pawnFork(chess, color);
    if (fork != null) {
      final name = TacticsDetector.pieceName(fork.piece);
      return '$base There\'s a fork available! Try moving your $name to ${fork.square} to attack two pieces at once.';
    }

    return base;
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
      'Watch out — that move might be a {l}, losing ~{p} pawns. Look again!',
      'Before playing {m}, double-check: you may be giving up ~{p} pawns.',
      'That could be a {l}! You\'d lose about {p} pawns — is there a better option?',
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

    // Detect opening played
    final opening = detectOpening(moveHistory);

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
          comment:
              'This move lost about $pawns pawns of material — the position became significantly harder after this.',
          better:
              'Before capturing or moving here, always ask: "What does my opponent get back?"',
        ));
      }

      if (swing >= 150 && swing > bestGain) {
        bestGain = swing;
        bestMove = BestMoveEntry(
          move: san,
          comment:
              'This move won about ${(swing / 100).toStringAsFixed(1)} pawns of material — great tactical alertness!',
        );
      }
    }

    var score = 70 - (mistakes.length * 10) + (bestMove != null ? 5 : 0);
    score += (moveHistory.length / 8).clamp(0, 10).toInt();
    score = score.clamp(10, 95);

    return PostGameAnalysis(
      score: score,
      summary: _buildSummary(moveHistory.length, score, opening?.name),
      mistakes: mistakes,
      bestMove: bestMove,
      advice: _buildAdvice(mistakes, moveHistory.length, opening),
    );
  }

  // ── Opening tip ───────────────────────────────────────────────────────────

  String _openingTip(chess_lib.Chess chess, chess_lib.Color color,
      List<String> moveHistory, int moveNum, String lastMove) {
    // Identified opening → give the opening-specific plan
    final opening = detectOpening(moveHistory);
    if (opening != null &&
        moveNum >= opening.moves.length &&
        moveNum <= opening.moves.length + 5) {
      return 'You\'re playing the ${opening.name}. '
          'Key plan: ${opening.plan}';
    }

    // Generic opening principle checks
    final isWhite = color == chess_lib.Color.WHITE;
    final undeveloped = _undevelopedCount(chess, color,
        isWhite ? ['b1', 'g1', 'c1', 'f1'] : ['b8', 'g8', 'c8', 'f8']);
    final notCastled =
        _findKing(chess, color) == (isWhite ? 'e1' : 'e8');

    if (moveNum <= 4 && _centerPawns(chess, color) == 0) {
      return 'Opening principle: fight for the center! A pawn on e4 or d4 gives your pieces room and controls key squares.';
    }
    if (undeveloped >= 3 && moveNum >= 4) {
      return 'Your knights and bishops are still on their starting squares. Develop them before pushing more pawns or moving the queen out early.';
    }
    if (notCastled && undeveloped <= 1 && moveNum >= 6) {
      return 'Your pieces look well developed! Castle now to protect your king and connect your rooks — two benefits in one move.';
    }

    const tips = [
      'Each opening move should do something useful: develop a piece, control the center, or improve king safety.',
      'Avoid moving the same piece twice in the opening unless you gain material or are forced to.',
      'After developing your pieces, look for an opportunity to castle. A safe king is a long-term advantage.',
      'Think about the center — whoever controls e4, d4, e5, d5 usually has more space to maneuver.',
    ];
    return tips[moveNum % tips.length];
  }

  // ── Middlegame / endgame tip ───────────────────────────────────────────────

  String _middlegameTip(chess_lib.Chess chess, String lastMove, int moveNum) {
    if (_isEndgame(chess)) {
      return 'Endgame reached! Activate your king — it becomes a powerful attacker and defender once queens are off the board. Push your passed pawns!';
    }

    final balance = _materialBalance(chess);
    if (lastMove.contains('x') && balance.abs() >= 200) {
      final side = balance > 0 ? 'ahead' : 'behind';
      final diff = (balance.abs() / 100).toStringAsFixed(1);
      return balance > 0
          ? 'After that exchange, you\'re $side by ~$diff pawns. Simplify toward an endgame to convert your advantage.'
          : 'After that exchange, you\'re $side by ~$diff pawns. Look for active counterplay, tactics, or piece activity to compensate.';
    }

    const tips = [
      'Before every move, check: does my opponent have a threat I must deal with first?',
      'Find your least active piece and ask: what\'s the best square for it? Improving one piece per move adds up.',
      'Scan for tactics: forks (one piece attacks two), pins (piece can\'t move safely), and skewers (reverse pin).',
      'Rooks belong on open files and the 7th rank. If the center is open, activate your rooks now.',
      'Passed pawns — pawns with no opposing pawns on the same or adjacent files — are a big endgame advantage. Push them!',
      'Don\'t rush: if you\'re ahead in material, simplify. If you\'re behind, create complications and look for counterplay.',
      'Weak squares near the opponent\'s king are targets. Plant a piece on a weak square and your opponent can\'t easily dislodge it.',
    ];
    return tips[moveNum % tips.length];
  }

  // ── AI move explanation ───────────────────────────────────────────────────

  String _explainMove(String san) {
    if (san == 'O-O') {
      return 'I castled kingside to move my king to safety and connect my rooks.';
    }
    if (san == 'O-O-O') {
      return 'I castled queenside to secure my king and activate the queenside rook.';
    }
    if (san.contains('#')) return 'Checkmate — well played fighting to the end!';
    if (san.contains('+')) {
      return 'I played $san to give check, forcing you to respond immediately and limiting your choices.';
    }
    if (san.contains('x')) {
      if (san[0] == san[0].toLowerCase()) {
        return 'My pawn captured on ${_strip(san)} — winning material and opening the file for my rooks.';
      }
      final name = _pieceName(san[0]);
      return 'I captured with my $name (${_strip(san)}) — winning material or exchanging to reach a better position.';
    }
    if (san.contains('=')) {
      return 'Pawn promotion! My pawn reached the back rank and became a queen — the most powerful piece on the board.';
    }
    if (san[0] == san[0].toLowerCase()) {
      return 'I advanced my pawn to ${_strip(san)} — claiming space and restricting your piece mobility.';
    }
    final name = _pieceName(san[0]);
    return 'I moved my $name to ${_strip(san)} — improving its activity and increasing pressure on your position.';
  }

  // ── Post-game helpers ─────────────────────────────────────────────────────

  String _buildSummary(int moveCount, int score, String? openingName) {
    final length =
        moveCount <= 20 ? 'quick' : moveCount <= 40 ? 'solid' : 'long';
    final openingStr =
        openingName != null ? ' in the $openingName' : '';
    if (score >= 65) {
      return 'Great $length game$openingStr of $moveCount moves! You kept good material balance and showed strong positional awareness. Keep building on this!';
    } else if (score >= 45) {
      return 'Decent $length game$openingStr — the position stayed competitive, with some strong moments. Study the key mistakes below to level up.';
    }
    return 'Tough $length game$openingStr of $moveCount moves. Every game teaches something — dig into the mistakes below and you\'ll improve quickly!';
  }

  String _buildAdvice(List<MistakeEntry> mistakes, int moveCount,
      opening) {
    if (mistakes.isEmpty) {
      return 'No major material swings — excellent game! Work on converting small advantages cleanly in future games.';
    }
    if (moveCount <= 20) {
      return 'Focus on opening principles: develop all minor pieces, control the center, and castle before move 10 when possible.';
    }
    return 'Study the positions before your biggest material losses. Before each capture, always ask: "What does my opponent get back?"';
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

  int _undevelopedCount(
      chess_lib.Chess chess, chess_lib.Color color, List<String> starts) {
    var count = 0;
    for (final sq in starts) {
      final p = chess.get(sq);
      if (p != null &&
          p.color == color &&
          (p.type == chess_lib.PieceType.KNIGHT ||
              p.type == chess_lib.PieceType.BISHOP)) count++;
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
        if (p?.type == chess_lib.PieceType.KING && p?.color == color) {
          return '$f$r';
        }
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
        if (p.type == chess_lib.PieceType.KNIGHT ||
            p.type == chess_lib.PieceType.BISHOP) minors++;
      }
    }
    return queens == 0 || (queens <= 1 && minors <= 2);
  }

  chess_lib.Color _chessColor(PlayerColor c) =>
      c == PlayerColor.white ? chess_lib.Color.WHITE : chess_lib.Color.BLACK;

  String _pieceName(String letter) {
    const n = {
      'N': 'knight', 'B': 'bishop', 'R': 'rook', 'Q': 'queen', 'K': 'king'
    };
    return n[letter] ?? 'piece';
  }

  String _strip(String san) => san.replaceAll(RegExp(r'[x+=+#!?]'), '');
}
