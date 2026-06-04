import 'package:chess/chess.dart' as chess_lib;

/// Geometric tactical analysis — detects hanging pieces, free captures,
/// and fork patterns without requiring any network calls or LLM.
///
/// Uses pseudo-legal coverage (ignores pins) which is accurate enough
/// for beginner coaching while remaining fast and fully offline.
class TacticsDetector {
  static const _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
  static const _ranks = ['1', '2', '3', '4', '5', '6', '7', '8'];

  static const _values = {
    chess_lib.PieceType.PAWN: 100,
    chess_lib.PieceType.KNIGHT: 300,
    chess_lib.PieceType.BISHOP: 325,
    chess_lib.PieceType.ROOK: 500,
    chess_lib.PieceType.QUEEN: 900,
    chess_lib.PieceType.KING: 10000,
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns [playerColor]'s most at-risk piece that opponent can capture
  /// for a net material gain, or null if nothing is hanging.
  static TacticalHint? hangingPiece(
      chess_lib.Chess chess, chess_lib.Color playerColor) {
    final opp = _opp(playerColor);
    TacticalHint? worst;

    for (final f in _files) {
      for (final r in _ranks) {
        final sq = '$f$r';
        final p = chess.get(sq);
        if (p == null ||
            p.color != playerColor ||
            p.type == chess_lib.PieceType.KING) continue;

        final pVal = _values[p.type] ?? 0;
        final minAtk = _minAttackerValue(chess, sq, opp);
        if (minAtk == null) continue; // not attacked at all

        final defended = _squareCoveredBy(chess, sq, playerColor);
        final gain =
            defended ? (pVal - minAtk).clamp(0, 9999) : pVal;

        if (gain >= 100 && (worst == null || gain > worst.gain)) {
          worst = TacticalHint(
            type: TacticType.hangingPiece,
            square: sq,
            piece: p.type,
            gain: gain,
          );
        }
      }
    }
    return worst;
  }

  /// Returns the best profitable capture [playerColor] can make in the
  /// current position, or null if nothing is immediately winnable.
  static TacticalHint? bestCapture(
      chess_lib.Chess chess, chess_lib.Color playerColor) {
    final opp = _opp(playerColor);
    TacticalHint? best;

    for (final f in _files) {
      for (final r in _ranks) {
        final sq = '$f$r';
        final target = chess.get(sq);
        if (target == null ||
            target.color != opp ||
            target.type == chess_lib.PieceType.KING) continue;

        final targetVal = _values[target.type] ?? 0;
        final minAtk = _minAttackerValue(chess, sq, playerColor);
        if (minAtk == null) continue; // player doesn't attack this square

        final defended = _squareCoveredBy(chess, sq, opp);
        final gain =
            defended ? (targetVal - minAtk).clamp(0, 9999) : targetVal;

        if (gain >= 100 && (best == null || gain > best.gain)) {
          best = TacticalHint(
            type: TacticType.freeCapture,
            square: sq,
            piece: target.type,
            gain: gain,
          );
        }
      }
    }
    return best;
  }

  /// Detect a knight fork opportunity: a legal knight destination that
  /// simultaneously attacks 2+ valuable opponent pieces.
  static TacticalHint? knightFork(
      chess_lib.Chess chess, chess_lib.Color playerColor) {
    final opp = _opp(playerColor);

    const deltas = [
      [2, 1], [2, -1], [-2, 1], [-2, -1],
      [1, 2], [1, -2], [-1, 2], [-1, -2],
    ];

    for (final f in _files) {
      for (final r in _ranks) {
        final sq = '$f$r';
        final knight = chess.get(sq);
        if (knight?.type != chess_lib.PieceType.KNIGHT ||
            knight?.color != playerColor) continue;

        final fi = _files.indexOf(f);
        final ri = _ranks.indexOf(r);

        for (final [df, dr] in deltas) {
          final nf = fi + df;
          final nr = ri + dr;
          if (nf < 0 || nf > 7 || nr < 0 || nr > 7) continue;

          final dest = '${_files[nf]}${_ranks[nr]}';
          if (chess.get(dest)?.color == playerColor) continue;

          // Count valuable opponent pieces attacked from dest
          var attackCount = 0;
          var totalValue = 0;
          var forksKing = false;

          for (final [af, ar] in deltas) {
            final atf = nf + af;
            final atr = nr + ar;
            if (atf < 0 || atf > 7 || atr < 0 || atr > 7) continue;

            final atkSq = '${_files[atf]}${_ranks[atr]}';
            if (atkSq == sq) continue; // don't double-count origin
            final victim = chess.get(atkSq);

            if (victim?.color == opp) {
              attackCount++;
              if (victim!.type == chess_lib.PieceType.KING) {
                forksKing = true;
              } else {
                totalValue += _values[victim.type] ?? 0;
              }
            }
          }

          if (attackCount >= 2 && (forksKing || totalValue >= 500)) {
            return TacticalHint(
              type: TacticType.knightFork,
              square: dest,
              piece: chess_lib.PieceType.KNIGHT,
              gain: totalValue,
            );
          }
        }
      }
    }
    return null;
  }

  /// Detect a pawn fork: a single pawn push that attacks two non-pawn
  /// opponent pieces diagonally worth at least 6 pawns combined.
  static TacticalHint? pawnFork(
      chess_lib.Chess chess, chess_lib.Color playerColor) {
    final opp = _opp(playerColor);
    final isWhite = playerColor == chess_lib.Color.WHITE;
    final dir = isWhite ? 1 : -1;

    for (final f in _files) {
      for (final r in _ranks) {
        final sq = '$f$r';
        final pawn = chess.get(sq);
        if (pawn?.type != chess_lib.PieceType.PAWN ||
            pawn?.color != playerColor) continue;

        final fi = _files.indexOf(f);
        final ri = _ranks.indexOf(r);
        final pushRank = ri + dir;
        if (pushRank < 0 || pushRank > 7) continue;
        final pushSq = '${_files[fi]}${_ranks[pushRank]}';
        if (chess.get(pushSq) != null) continue; // blocked

        var attackCount = 0;
        var totalValue = 0;

        for (final df in [-1, 1]) {
          final atkFile = fi + df;
          final atkRank = pushRank + dir;
          if (atkFile < 0 || atkFile > 7 || atkRank < 0 || atkRank > 7) continue;

          final atkSq = '${_files[atkFile]}${_ranks[atkRank]}';
          final victim = chess.get(atkSq);

          if (victim?.color == opp &&
              victim!.type != chess_lib.PieceType.PAWN) {
            attackCount++;
            totalValue += _values[victim.type] ?? 0;
          }
        }

        if (attackCount == 2 && totalValue >= 600) {
          return TacticalHint(
            type: TacticType.pawnFork,
            square: pushSq,
            piece: chess_lib.PieceType.PAWN,
            gain: totalValue,
          );
        }
      }
    }
    return null;
  }

  // ── Geometric coverage ────────────────────────────────────────────────────

  /// Minimum piece value among [color]'s pieces that geometrically cover
  /// [square]. Returns null if the square is not attacked by [color].
  static int? _minAttackerValue(
      chess_lib.Chess chess, String square, chess_lib.Color color) {
    final ti = _fi(square[0]);
    final tj = _ri(square[1]);
    int? minVal;

    for (final f in _files) {
      for (final r in _ranks) {
        final sq = '$f$r';
        if (sq == square) continue;
        final p = chess.get(sq);
        if (p == null || p.color != color) continue;

        if (_covers(chess, _fi(f), _ri(r), ti, tj, p.type, color)) {
          final v = _values[p.type] ?? 9999;
          if (minVal == null || v < minVal) minVal = v;
        }
      }
    }
    return minVal;
  }

  static bool _squareCoveredBy(
      chess_lib.Chess chess, String square, chess_lib.Color color) {
    return _minAttackerValue(chess, square, color) != null;
  }

  /// Whether a piece of [type]/[color] at (ff,fr) geometrically covers (tf,tr).
  /// Ignores pins — this is intentional for fast, approximate coaching.
  static bool _covers(chess_lib.Chess chess, int ff, int fr, int tf, int tr,
      chess_lib.PieceType type, chess_lib.Color color) {
    final df = tf - ff;
    final dr = tr - fr;

    switch (type) {
      case chess_lib.PieceType.PAWN:
        final fwd = color == chess_lib.Color.WHITE ? 1 : -1;
        return dr == fwd && df.abs() == 1;

      case chess_lib.PieceType.KNIGHT:
        return (df.abs() == 2 && dr.abs() == 1) ||
            (df.abs() == 1 && dr.abs() == 2);

      case chess_lib.PieceType.BISHOP:
        if (df.abs() != dr.abs() || df == 0) return false;
        return _clear(chess, ff, fr, tf, tr);

      case chess_lib.PieceType.ROOK:
        if ((df == 0) == (dr == 0)) return false; // must be straight, not same sq
        return _clear(chess, ff, fr, tf, tr);

      case chess_lib.PieceType.QUEEN:
        final diag = df.abs() == dr.abs() && df != 0;
        final straight = (df == 0) != (dr == 0);
        if (!diag && !straight) return false;
        return _clear(chess, ff, fr, tf, tr);

      case chess_lib.PieceType.KING:
        return df.abs() <= 1 && dr.abs() <= 1 && (df != 0 || dr != 0);

      default:
        return false;
    }
  }

  /// Whether there are no pieces between (ff,fr) and (tf,tr) exclusive.
  static bool _clear(
      chess_lib.Chess chess, int ff, int fr, int tf, int tr) {
    final sf = (tf - ff).sign;
    final sr = (tr - fr).sign;
    var f = ff + sf;
    var r = fr + sr;
    while (f != tf || r != tr) {
      if (chess.get('${_files[f]}${_ranks[r]}') != null) return false;
      f += sf;
      r += sr;
    }
    return true;
  }

  static int _fi(String file) => _files.indexOf(file);
  static int _ri(String rank) => _ranks.indexOf(rank);

  static chess_lib.Color _opp(chess_lib.Color c) =>
      c == chess_lib.Color.WHITE ? chess_lib.Color.BLACK : chess_lib.Color.WHITE;

  // ── Utilities ─────────────────────────────────────────────────────────────

  static String pieceName(chess_lib.PieceType type) {
    const n = {
      chess_lib.PieceType.PAWN: 'pawn',
      chess_lib.PieceType.KNIGHT: 'knight',
      chess_lib.PieceType.BISHOP: 'bishop',
      chess_lib.PieceType.ROOK: 'rook',
      chess_lib.PieceType.QUEEN: 'queen',
      chess_lib.PieceType.KING: 'king',
    };
    return n[type] ?? 'piece';
  }
}

// ── Data types ──────────────────────────────────────────────────────────────

enum TacticType { hangingPiece, freeCapture, knightFork, pawnFork }

class TacticalHint {
  final TacticType type;
  final String square;
  final chess_lib.PieceType piece;
  final int gain; // centipawns

  const TacticalHint({
    required this.type,
    required this.square,
    required this.piece,
    required this.gain,
  });
}
