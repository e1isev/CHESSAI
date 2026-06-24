import 'package:chess/chess.dart' as chess_lib;

/// Geometric tactical and strategic pattern detection.
/// All methods are pure, side-effect-free, and offline.
class TacticsDetector {
  static const _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
  static const _ranks = ['1', '2', '3', '4', '5', '6', '7', '8'];

  static final _values = {
    chess_lib.PieceType.PAWN: 100,
    chess_lib.PieceType.KNIGHT: 300,
    chess_lib.PieceType.BISHOP: 325,
    chess_lib.PieceType.ROOK: 500,
    chess_lib.PieceType.QUEEN: 900,
    chess_lib.PieceType.KING: 10000,
  };

  // ── Existing: hanging piece & captures ────────────────────────────────────

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
        if (minAtk == null) continue;

        final defended = _squareCoveredBy(chess, sq, playerColor);
        final gain = defended ? (pVal - minAtk).clamp(0, 9999) : pVal;

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
        if (minAtk == null) continue;

        final defended = _squareCoveredBy(chess, sq, opp);
        final gain = defended ? (targetVal - minAtk).clamp(0, 9999) : targetVal;

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

  // ── Existing: forks ───────────────────────────────────────────────────────

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

          var attackCount = 0;
          var totalValue = 0;
          var forksKing = false;

          for (final [af, ar] in deltas) {
            final atf = nf + af;
            final atr = nr + ar;
            if (atf < 0 || atf > 7 || atr < 0 || atr > 7) continue;

            final atkSq = '${_files[atf]}${_ranks[atr]}';
            if (atkSq == sq) continue;
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
        if (chess.get(pushSq) != null) continue;

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

  // ── NEW: Pin detection ────────────────────────────────────────────────────

  /// Finds pieces of [playerColor] that are absolutely pinned to their king
  /// (moving them would expose the king to check).
  static List<PinInfo> detectPins(
      chess_lib.Chess chess, chess_lib.Color playerColor) {
    final pins = <PinInfo>[];
    final kingSquare = _findKing(chess, playerColor);
    if (kingSquare == null) return pins;

    final kf = _fi(kingSquare[0]);
    final kr = _ri(kingSquare[1]);

    // Scan outward from the king in all 8 directions
    const directions = [
      [1, 0], [-1, 0], [0, 1], [0, -1],
      [1, 1], [1, -1], [-1, 1], [-1, -1],
    ];

    for (final [df, dr] in directions) {
      String? pinnedSq;
      var f = kf + df;
      var r = kr + dr;

      while (f >= 0 && f <= 7 && r >= 0 && r <= 7) {
        final sq = '${_files[f]}${_ranks[r]}';
        final p = chess.get(sq);

        if (p != null) {
          if (p.color == playerColor) {
            if (pinnedSq == null) {
              pinnedSq = sq; // first friendly piece in this ray
            } else {
              break; // second friendly piece blocks any pin
            }
          } else {
            // Opponent piece — is it a slider that attacks along this ray?
            if (pinnedSq != null && _sliderCoversRay(p.type, df, dr)) {
              pins.add(PinInfo(
                pinnedSquare: pinnedSq,
                pinnedPiece: chess.get(pinnedSq)!.type,
                attackerSquare: sq,
                attackerPiece: p.type,
              ));
            }
            break;
          }
        }
        f += df;
        r += dr;
      }
    }
    return pins;
  }

  /// Finds opponent pieces that are pinned (player can exploit the pin).
  static List<PinInfo> detectOpponentPins(
      chess_lib.Chess chess, chess_lib.Color playerColor) {
    return detectPins(chess, _opp(playerColor))
        .where((pin) {
          // Only report pins worth exploiting (pinned piece is valuable)
          final val = _values[pin.pinnedPiece] ?? 0;
          return val >= 300; // knight or better
        })
        .toList();
  }

  // ── NEW: Passed pawns ─────────────────────────────────────────────────────

  /// Returns squares of [playerColor]'s passed pawns.
  /// A passed pawn has no opposing pawns on the same or adjacent files ahead.
  static List<String> passedPawns(
      chess_lib.Chess chess, chess_lib.Color playerColor) {
    final opp = _opp(playerColor);
    final isWhite = playerColor == chess_lib.Color.WHITE;
    final passed = <String>[];

    for (final f in _files) {
      for (final r in _ranks) {
        final sq = '$f$r';
        final p = chess.get(sq);
        if (p?.type != chess_lib.PieceType.PAWN || p?.color != playerColor) continue;

        final fi = _files.indexOf(f);
        final ri = _ranks.indexOf(r);
        var isPassed = true;

        // Check same and adjacent files ahead for opponent pawns
        for (final df in [-1, 0, 1]) {
          final af = fi + df;
          if (af < 0 || af > 7) continue;

          // Scan all ranks ahead of this pawn
          final rankRange = isWhite
              ? List.generate(7 - ri, (i) => ri + 1 + i)
              : List.generate(ri, (i) => ri - 1 - i);

          for (final ar in rankRange) {
            final aSq = '${_files[af]}${_ranks[ar]}';
            final ap = chess.get(aSq);
            if (ap?.type == chess_lib.PieceType.PAWN && ap?.color == opp) {
              isPassed = false;
              break;
            }
          }
          if (!isPassed) break;
        }

        if (isPassed) passed.add(sq);
      }
    }
    return passed;
  }

  // ── NEW: Back-rank weakness ───────────────────────────────────────────────

  /// Returns true if [playerColor]'s king is vulnerable to a back-rank mate.
  /// Conditions: king on home rank, 0 escape squares on next rank,
  /// and opponent has a rook or queen.
  static bool hasBackRankThreat(
      chess_lib.Chess chess, chess_lib.Color playerColor) {
    final opp = _opp(playerColor);
    final isWhite = playerColor == chess_lib.Color.WHITE;
    final homeRank = isWhite ? '1' : '8';
    final safeRank = isWhite ? '2' : '7';

    final kingSquare = _findKing(chess, playerColor);
    if (kingSquare == null || kingSquare[1] != homeRank) return false;

    // Count escape squares on the safe rank adjacent to king file
    final kf = _fi(kingSquare[0]);
    var escapeSquares = 0;

    for (final df in [-1, 0, 1]) {
      final ef = kf + df;
      if (ef < 0 || ef > 7) continue;
      final esc = '${_files[ef]}$safeRank';
      final p = chess.get(esc);
      // Square is safe if empty and not controlled by opponent
      if (p == null && !_squareCoveredBy(chess, esc, opp)) {
        escapeSquares++;
      }
    }

    if (escapeSquares > 0) return false;

    // Does opponent have a rook or queen?
    for (final f in _files) {
      for (final r in _ranks) {
        final p = chess.get('$f$r');
        if (p?.color == opp &&
            (p!.type == chess_lib.PieceType.ROOK ||
                p.type == chess_lib.PieceType.QUEEN)) {
          return true;
        }
      }
    }
    return false;
  }

  // ── NEW: Pawn structure ───────────────────────────────────────────────────

  /// Returns pawn structure weaknesses for [playerColor].
  static PawnStructure analyzePawnStructure(
      chess_lib.Chess chess, chess_lib.Color playerColor) {
    final doubled = <String>[];
    final isolated = <String>[];

    // Count pawns per file
    final pawnsPerFile = <int, List<String>>{};
    for (final f in _files) {
      final fi = _files.indexOf(f);
      pawnsPerFile[fi] = [];
      for (final r in _ranks) {
        final p = chess.get('$f$r');
        if (p?.type == chess_lib.PieceType.PAWN && p?.color == playerColor) {
          pawnsPerFile[fi]!.add('$f$r');
        }
      }
    }

    for (int fi = 0; fi < 8; fi++) {
      final pawns = pawnsPerFile[fi] ?? [];

      // Doubled pawns
      if (pawns.length >= 2) {
        doubled.add(pawns.first);
      }

      // Isolated pawns (no friendly pawns on adjacent files)
      if (pawns.isNotEmpty) {
        final hasLeft = fi > 0 && (pawnsPerFile[fi - 1]?.isNotEmpty ?? false);
        final hasRight = fi < 7 && (pawnsPerFile[fi + 1]?.isNotEmpty ?? false);
        if (!hasLeft && !hasRight) {
          isolated.addAll(pawns);
        }
      }
    }

    return PawnStructure(doubled: doubled, isolated: isolated);
  }

  // ── NEW: Open-file rooks ──────────────────────────────────────────────────

  /// Returns squares of [playerColor]'s rooks that are on open or semi-open files.
  static List<RookFileInfo> openFileRooks(
      chess_lib.Chess chess, chess_lib.Color playerColor) {
    final opp = _opp(playerColor);
    final results = <RookFileInfo>[];

    for (final f in _files) {
      var hasOwnPawn = false;
      var hasOppPawn = false;
      String? rookSquare;

      for (final r in _ranks) {
        final sq = '$f$r';
        final p = chess.get(sq);
        if (p == null) continue;
        if (p.type == chess_lib.PieceType.PAWN) {
          if (p.color == playerColor) hasOwnPawn = true;
          else hasOppPawn = true;
        }
        if (p.type == chess_lib.PieceType.ROOK && p.color == playerColor) {
          rookSquare = sq;
        }
      }

      if (rookSquare == null) continue;

      if (!hasOwnPawn && !hasOppPawn) {
        results.add(RookFileInfo(square: rookSquare, file: f, isOpen: true));
      } else if (!hasOwnPawn && hasOppPawn) {
        results.add(RookFileInfo(square: rookSquare, file: f, isOpen: false));
      }
    }

    return results;
  }

  // ── NEW: King safety ──────────────────────────────────────────────────────

  /// Returns a 0–100 king safety score for [playerColor].
  /// Higher = safer. Considers pawn shield and open files near king.
  static int kingSafetyScore(
      chess_lib.Chess chess, chess_lib.Color playerColor) {
    final kingSquare = _findKing(chess, playerColor);
    if (kingSquare == null) return 50;

    final isWhite = playerColor == chess_lib.Color.WHITE;
    final kf = _fi(kingSquare[0]);
    final kr = _ri(kingSquare[1]);
    final homeRank = isWhite ? 0 : 7; // rank index

    // Bonus: king on the edge / castled side
    var score = 60;

    // Pawn shield: pawns on the 2 ranks in front of the king
    final shieldDir = isWhite ? 1 : -1;
    var shieldPawns = 0;
    for (final df in [-1, 0, 1]) {
      final sf = kf + df;
      if (sf < 0 || sf > 7) continue;
      for (final dr in [1, 2]) {
        final sr = kr + shieldDir * dr;
        if (sr < 0 || sr > 7) continue;
        final sq = '${_files[sf]}${_ranks[sr]}';
        final p = chess.get(sq);
        if (p?.type == chess_lib.PieceType.PAWN && p?.color == playerColor) {
          shieldPawns++;
        }
      }
    }
    score += shieldPawns * 8;

    // Penalty: open or semi-open files adjacent to king
    for (final df in [-1, 0, 1]) {
      final sf = kf + df;
      if (sf < 0 || sf > 7) continue;
      var hasPawn = false;
      for (final r in _ranks) {
        final p = chess.get('${_files[sf]}$r');
        if (p?.type == chess_lib.PieceType.PAWN && p?.color == playerColor) {
          hasPawn = true;
          break;
        }
      }
      if (!hasPawn) score -= 12;
    }

    // Bonus: king far from center (on the wing) in middlegame
    final distFromCenter = (kf - 3).abs().clamp(0, 3) + (kf - 4).abs().clamp(0, 3);
    if (kr == homeRank) score += distFromCenter * 3;

    return score.clamp(0, 100);
  }

  // ── Helpers: geometry ─────────────────────────────────────────────────────

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
        if ((df == 0) == (dr == 0)) return false;
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

  static bool _clear(chess_lib.Chess chess, int ff, int fr, int tf, int tr) {
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

  /// Whether a sliding piece type can attack along a ray defined by (df, dr).
  static bool _sliderCoversRay(chess_lib.PieceType type, int df, int dr) {
    final isDiag = df.abs() == dr.abs();
    final isStraight = df == 0 || dr == 0;
    switch (type) {
      case chess_lib.PieceType.ROOK: return isStraight;
      case chess_lib.PieceType.BISHOP: return isDiag;
      case chess_lib.PieceType.QUEEN: return isStraight || isDiag;
      default: return false;
    }
  }

  static String? _findKing(chess_lib.Chess chess, chess_lib.Color color) {
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

  static int _fi(String file) => _files.indexOf(file);
  static int _ri(String rank) => _ranks.indexOf(rank);

  static chess_lib.Color _opp(chess_lib.Color c) =>
      c == chess_lib.Color.WHITE ? chess_lib.Color.BLACK : chess_lib.Color.WHITE;

  static final _pieceNames = {
    chess_lib.PieceType.PAWN: 'pawn',
    chess_lib.PieceType.KNIGHT: 'knight',
    chess_lib.PieceType.BISHOP: 'bishop',
    chess_lib.PieceType.ROOK: 'rook',
    chess_lib.PieceType.QUEEN: 'queen',
    chess_lib.PieceType.KING: 'king',
  };

  static String pieceName(chess_lib.PieceType type) {
    return _pieceNames[type] ?? 'piece';
  }
}

// ── Data types ──────────────────────────────────────────────────────────────

enum TacticType { hangingPiece, freeCapture, knightFork, pawnFork }

class TacticalHint {
  final TacticType type;
  final String square;
  final chess_lib.PieceType piece;
  final int gain;

  const TacticalHint({
    required this.type,
    required this.square,
    required this.piece,
    required this.gain,
  });
}

class PinInfo {
  final String pinnedSquare;
  final chess_lib.PieceType pinnedPiece;
  final String attackerSquare;
  final chess_lib.PieceType attackerPiece;

  const PinInfo({
    required this.pinnedSquare,
    required this.pinnedPiece,
    required this.attackerSquare,
    required this.attackerPiece,
  });
}

class PawnStructure {
  final List<String> doubled;
  final List<String> isolated;

  const PawnStructure({required this.doubled, required this.isolated});
}

class RookFileInfo {
  final String square;
  final String file;
  final bool isOpen; // true = fully open, false = semi-open

  const RookFileInfo({
    required this.square,
    required this.file,
    required this.isOpen,
  });
}
