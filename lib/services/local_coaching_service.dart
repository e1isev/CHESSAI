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
    final opp = color == chess_lib.Color.WHITE
        ? chess_lib.Color.BLACK
        : chess_lib.Color.WHITE;

    // ── 1. Hanging piece (immediate danger) ──────────────────────────────────
    final hanging = TacticsDetector.hangingPiece(chess, color);
    if (hanging != null) {
      final name = TacticsDetector.pieceName(hanging.piece);
      final pawns = (hanging.gain / 100).toStringAsFixed(1);
      return hanging.gain >= 300
          ? 'Danger — Hanging Piece: Your $name on ${hanging.square} is undefended and can be captured for ~$pawns pawns! A "hanging" piece is one that can be taken for free. Move it to safety or add a defender immediately.'
          : 'Watch out — Hanging Piece: Your $name on ${hanging.square} is at risk for a ~$pawns-pawn swing. Make sure it\'s properly defended before making another plan.';
    }

    // ── 2. Back-rank weakness ─────────────────────────────────────────────────
    if (TacticsDetector.hasBackRankThreat(chess, color)) {
      return 'Warning — Back-Rank Weakness: Your king has no escape squares on the back rank and your opponent has a rook or queen. This is the classic "back-rank mate" pattern! Play h3 (or h6 as Black) to create a "luft" — a breathing square — for your king. This is a basic king safety principle.';
    }

    // ── 3. Player\'s own pieces are pinned ────────────────────────────────────
    final myPins = TacticsDetector.detectPins(chess, color);
    if (myPins.isNotEmpty) {
      final pin = myPins.first;
      final pinnedName = TacticsDetector.pieceName(pin.pinnedPiece);
      final attackerName = TacticsDetector.pieceName(pin.attackerPiece);
      return 'Careful — Pin: Your $pinnedName on ${pin.pinnedSquare} is pinned by the opponent\'s $attackerName on ${pin.attackerSquare}. A pinned piece can\'t move safely because it would expose a more valuable piece behind it. Break the pin by blocking with another piece, moving the piece behind it, or capturing the pinning piece.';
    }

    // ── 4. Opponent has pinned pieces (exploit it) ───────────────────────────
    final oppPins = TacticsDetector.detectOpponentPins(chess, color);
    if (oppPins.isNotEmpty) {
      final pin = oppPins.first;
      final pinnedName = TacticsDetector.pieceName(pin.pinnedPiece);
      return 'Opportunity — Exploit the Pin: Your opponent\'s ${pinnedName} on ${pin.pinnedSquare} is pinned — it can\'t safely move! A pinned piece is a weak piece. Attack it with a pawn or another piece to win material, since the pinned piece can\'t run.';
    }

    // ── 5. Fork opportunities ─────────────────────────────────────────────────
    final fork = TacticsDetector.knightFork(chess, color)
        ?? TacticsDetector.pawnFork(chess, color);
    if (fork != null) {
      final name = TacticsDetector.pieceName(fork.piece);
      final type = fork.piece == chess_lib.PieceType.KNIGHT ? 'Knight Fork' : 'Pawn Fork';
      return 'Tactic — $type: Your $name can move to ${fork.square} and attack two opponent pieces simultaneously! A "fork" is when one piece attacks two at once — your opponent can only save one, so you win the other. Don\'t miss this!';
    }

    // ── 6. Free captures ─────────────────────────────────────────────────────
    final capture = TacticsDetector.bestCapture(chess, color);
    if (capture != null && capture.gain >= 200) {
      final name = TacticsDetector.pieceName(capture.piece);
      final pawns = (capture.gain / 100).toStringAsFixed(1);
      return 'Free Material: You can capture the ${name} on ${capture.square} for approximately $pawns pawns of material with no loss! Always scan the board for undefended or underdefended pieces before choosing your move.';
    }

    // ── 7. Opening phase ──────────────────────────────────────────────────────
    if (moveNum <= 14) {
      return _openingTip(chess, color, moveHistory, moveNum, lastMove);
    }

    // ── 8. Passed pawns ───────────────────────────────────────────────────────
    final passed = TacticsDetector.passedPawns(chess, color);
    if (passed.isNotEmpty) {
      final sq = passed.first;
      final file = sq[0];
      return 'Advantage — Passed Pawn: You have a passed pawn on $sq! A "passed pawn" has no enemy pawns blocking its path to promotion on the $file-file. Passed pawns are one of the strongest long-term advantages — push it forward, support it with your rooks from behind, and aim to queen it!';
    }

    // ── 9. Open file rooks ────────────────────────────────────────────────────
    final openRooks = TacticsDetector.openFileRooks(chess, color);
    if (openRooks.isNotEmpty) {
      final rook = openRooks.first;
      final fileType = rook.isOpen ? 'open' : 'semi-open';
      return 'Strategy — Rook on ${rook.isOpen ? "Open" : "Semi-Open"} File: Your rook on ${rook.square} is on the ${rook.file}-file, which is $fileType. Rooks are at their strongest on open files with no pawns blocking their vision. Consider doubling your rooks on this file or invading the opponent\'s 7th rank — that\'s where rooks wreak havoc!';
    }

    // ── 10. Pawn structure weaknesses ────────────────────────────────────────
    final pawnStructure = TacticsDetector.analyzePawnStructure(chess, color);
    if (pawnStructure.doubled.isNotEmpty) {
      final sq = pawnStructure.doubled.first;
      final file = sq[0];
      return 'Structure — Doubled Pawns: You have doubled pawns on the $file-file (${sq}). Doubled pawns are a structural weakness because they can\'t protect each other and one of them is often a target. Try to trade one off, open a different file with your rooks, or use the half-open file your opponent gets as compensation for your activity.';
    }
    if (pawnStructure.isolated.isNotEmpty) {
      final sq = pawnStructure.isolated.first;
      final file = sq[0];
      return 'Structure — Isolated Pawn: Your pawn on $sq is isolated — there are no friendly pawns on adjacent files to protect it. Isolated pawns can be a target in the endgame. Either trade it off, use it to control key squares, or keep the position active so your opponent can\'t easily attack it.';
    }

    // ── 11. King safety warning ────────────────────────────────────────────────
    final kingScore = TacticsDetector.kingSafetyScore(chess, color);
    if (kingScore < 40 && !_isEndgame(chess)) {
      return 'King Safety Alert: Your king safety score is low — your king\'s pawn shield is thin and nearby files may be open for attack. In the middlegame, an exposed king is a huge liability. Consider creating "luft" (h3/g3 or h6/g6 as Black), keeping pawns in front of your king, and avoiding opening files near your king unless you\'re initiating the attack.';
    }

    // ── 12. Opponent king safety opportunity ──────────────────────────────────
    final oppKingScore = TacticsDetector.kingSafetyScore(chess, opp);
    if (oppKingScore < 35 && !_isEndgame(chess)) {
      return 'Attack — Weak Opponent King: Your opponent\'s king safety is poor! Their king has few pawn defenders and exposed files nearby. This is the moment to launch an attack — bring your pieces toward their king, open files with pawn pushes, and look for sacrifices to break through their defenses. Attack where your opponent is weakest!';
    }

    // ── 13. Middlegame / endgame ───────────────────────────────────────────────
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

    // Check if AI just created a pin
    final oppPins = TacticsDetector.detectOpponentPins(chess, color);
    if (oppPins.isNotEmpty) {
      final pin = oppPins.first;
      final name = TacticsDetector.pieceName(pin.pinnedPiece);
      return '$base Notice: I just pinned your ${name} on ${pin.pinnedSquare}! A pinned piece can\'t move safely. Attack it to win material.';
    }

    // Check for free captures
    final capture = TacticsDetector.bestCapture(chess, color);
    if (capture != null && capture.gain >= 200) {
      final name = TacticsDetector.pieceName(capture.piece);
      final pawns = (capture.gain / 100).toStringAsFixed(1);
      return '$base Now look carefully — you can win a $name on ${capture.square} for about $pawns pawns!';
    }

    // Check for fork opportunities
    final fork = TacticsDetector.knightFork(chess, color)
        ?? TacticsDetector.pawnFork(chess, color);
    if (fork != null) {
      final name = TacticsDetector.pieceName(fork.piece);
      return '$base There\'s a fork available! Try moving your $name to ${fork.square} to attack two pieces at once — that\'s a fork!';
    }

    // Check for passed pawn opportunity
    final passed = TacticsDetector.passedPawns(chess, color);
    if (passed.isNotEmpty) {
      return '$base You have a passed pawn on ${passed.first} — push it! Passed pawns are winning advantages.';
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

      if (swing <= -100 && mistakes.length < 5) {
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

    var score = 60 - (mistakes.length * 15) + (bestMove != null ? 5 : 0);
    score = score.clamp(5, 85);

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
      return 'Opening — ${opening.name}: You\'re playing the ${opening.name}. Key plan: ${opening.plan}';
    }

    // Generic opening principle checks
    final isWhite = color == chess_lib.Color.WHITE;
    final undeveloped = _undevelopedCount(chess, color,
        isWhite ? ['b1', 'g1', 'c1', 'f1'] : ['b8', 'g8', 'c8', 'f8']);
    final notCastled =
        _findKing(chess, color) == (isWhite ? 'e1' : 'e8');

    if (moveNum <= 4 && _centerPawns(chess, color) == 0) {
      return 'Opening Principle — Control the Center: Fight for the center with e4 or d4! The four central squares (e4, d4, e5, d5) are the most important squares in chess — whoever controls them has more space and better piece mobility. Central pawns are the foundation of a good opening.';
    }
    if (undeveloped >= 3 && moveNum >= 4) {
      return 'Opening Principle — Develop Your Pieces: Your knights and bishops are still on their starting squares. Development means bringing pieces to active squares where they control the center and support each other. Develop before pushing pawns or moving your queen — a general rule is "knights before bishops."';
    }
    if (notCastled && undeveloped <= 1 && moveNum >= 6) {
      return 'Opening Principle — Castle Now: Your pieces look well developed! Castling does two things at once: it moves your king to safety behind a pawn wall, and it connects your rooks so they can work together. Castle before launching your middlegame attack — a king in the center in an open position is a serious danger.';
    }

    const tips = [
      'Opening Principle: Every move in the opening should develop a piece, control the center, or improve king safety. Don\'t waste moves on unnecessary pawn pushes or moving the same piece twice.',
      'Opening Principle — Knights Before Bishops: Develop your knights first! Knights always go to f3/c3 (or f6/c6 for Black) — those squares are almost always correct. Bishops wait to see which direction the center goes before committing.',
      'Opening Principle — Don\'t Move Pieces Twice: Unless you gain material or are forced to, avoid moving the same piece twice in the opening. Every wasted move is a tempo your opponent uses to develop and attack.',
      'Opening Principle — Think About the Center: The player with more central space usually has more options. Your pawns and pieces should fight for e4, d4, e5, d5 — the heart of the board.',
    ];
    return tips[moveNum % tips.length];
  }

  // ── Middlegame / endgame tip ───────────────────────────────────────────────

  String _middlegameTip(chess_lib.Chess chess, String lastMove, int moveNum) {
    if (_isEndgame(chess)) {
      return 'Endgame — Activate Your King: Queens are off the board — your king becomes a powerful fighting piece! In the endgame, an active king is often the difference between winning and drawing. March your king toward the center, support your passed pawns from behind with rooks, and push your pawns to promote.';
    }

    final balance = _materialBalance(chess);
    if (lastMove.contains('x') && balance.abs() >= 200) {
      final diff = (balance.abs() / 100).toStringAsFixed(1);
      return balance > 0
          ? 'Material Advantage: You\'re ahead by ~$diff pawns of material. The winning strategy when ahead is to simplify — trade pieces (not pawns) to reach an endgame where your extra material decides the game. Don\'t give your opponent counterplay with unnecessary risks.'
          : 'Material Deficit: You\'re down by ~$diff pawns. When behind in material, avoid simplification — you need complications! Look for tactical tricks, active piece play, and counterattacking chances. Sometimes activity and initiative can compensate for material.';
    }

    const tips = [
      'Middlegame Principle — Check for Threats First: Before every move, scan the board and ask: "Does my opponent have a threat I must deal with?" Responding to threats before making your own plan is the first rule of good chess.',
      'Middlegame Principle — Improve Your Worst Piece: Find your least active piece and ask: "What\'s the best square for it?" Moving a piece from a bad square to a good one is often stronger than complicated tactics. Chess is won by small improvements.',
      'Middlegame Principle — Scan for Tactics: After your opponent moves, always check for tactical patterns: forks (one piece attacks two), pins (piece can\'t move safely), skewers (reverse pin), and discovered attacks (moving one piece to reveal another\'s attack).',
      'Middlegame Principle — Rooks on Open Files: Rooks are at their best on open files (files with no pawns). An open file is a highway for your rook to invade your opponent\'s position. Create open files by trading pawns, then double your rooks for maximum power.',
      'Middlegame Principle — Weak Squares: A "weak square" is one that can\'t be defended by a pawn. Plant a piece on a weak square in your opponent\'s camp — especially near their king — and it becomes an outpost that\'s very hard to dislodge.',
      'Middlegame Principle — When Ahead, Simplify: If you\'re winning, trade pieces to reduce your opponent\'s counterplay. If you\'re losing, keep pieces on the board and look for complications. The side with more material wants a simpler position.',
      'Middlegame Principle — King Safety: Never let your king safety slip, even when attacking. Make sure your king has a safe shelter — usually castled behind pawns. Before launching an attack, ask: "Is my own king safe enough?"',
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

  String _buildAdvice(List<MistakeEntry> mistakes, int moveCount, opening) {
    if (mistakes.isEmpty) {
      return 'No major material swings — excellent game! Work on converting small advantages cleanly in future games.';
    }
    if (moveCount <= 20) {
      return 'Focus on opening principles: develop all minor pieces (knights and bishops), control the center with pawns, and castle before move 10 when possible. A good opening leads to a good middlegame.';
    }
    return 'Study the positions before your biggest material losses. Before each capture ask: "What does my opponent get back?" This simple question prevents most tactical blunders.';
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
