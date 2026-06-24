import 'dart:async';
import 'dart:math';
import 'package:stockfish_chess_engine/stockfish_chess_engine.dart';

class _LevelConfig {
  final int depth;
  final int multiPv;
  final double blunderChance;

  const _LevelConfig({
    required this.depth,
    required this.multiPv,
    required this.blunderChance,
  });
}

// Each difficulty level also gets a fixed playing style, mimicking how
// chess.com bots are given personalities on top of their raw strength.
enum BotPersonality { balanced, aggressive, positional, defensive }

class StockfishService {
  Stockfish? _stockfish;
  StreamSubscription<String>? _subscription;
  Completer<String>? _bestMoveCompleter;
  bool _isReady = false;

  final Random _random = Random();
  final Map<int, String> _multipvMoves = {};
  int _currentDifficulty = 3;
  _LevelConfig? _currentConfig;
  String? _currentFen;

  // Difficulty is simulated the way chess.com bots do: by limiting search
  // depth (so weak levels literally can't see far enough to spot tactics)
  // and by injecting a chance to play a worse candidate move instead of the
  // engine's actual best move, drawn from a MultiPV list of alternatives.
  static const Map<int, _LevelConfig> _levelConfig = {
    1: _LevelConfig(depth: 3, multiPv: 6, blunderChance: 0.35),
    2: _LevelConfig(depth: 5, multiPv: 6, blunderChance: 0.22),
    3: _LevelConfig(depth: 8, multiPv: 5, blunderChance: 0.12),
    4: _LevelConfig(depth: 12, multiPv: 4, blunderChance: 0.05),
    5: _LevelConfig(depth: 18, multiPv: 3, blunderChance: 0.01),
  };

  static const Map<int, BotPersonality> _personalityByDifficulty = {
    1: BotPersonality.balanced,
    2: BotPersonality.aggressive,
    3: BotPersonality.positional,
    4: BotPersonality.defensive,
    5: BotPersonality.balanced,
  };

  BotPersonality personalityFor(int difficulty) =>
      _personalityByDifficulty[difficulty] ?? BotPersonality.balanced;

  Future<void> init() async {
    _stockfish = Stockfish();
    final readyCompleter = Completer<void>();

    _subscription = _stockfish!.stdout.listen((line) {
      if (line == 'readyok' && !readyCompleter.isCompleted) {
        _isReady = true;
        readyCompleter.complete();
      }
      if (line.contains('multipv')) {
        final pvMatch = RegExp(r'multipv (\d+)').firstMatch(line);
        final moveMatch = RegExp(r'\bpv (\S+)').firstMatch(line);
        if (pvMatch != null && moveMatch != null) {
          _multipvMoves[int.parse(pvMatch.group(1)!)] = moveMatch.group(1)!;
        }
      }
      if (line.startsWith('bestmove')) {
        final parts = line.split(' ');
        final fallback = parts.length >= 2 ? parts[1] : null;
        if (_bestMoveCompleter != null && !_bestMoveCompleter!.isCompleted) {
          _bestMoveCompleter!.complete(_chooseMove(fallback));
        }
      }
    });

    _stockfish!.stdin = 'uci';
    _stockfish!.stdin = 'isready';
    await readyCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Stockfish init timeout'),
    );
  }

  Future<String> getBestMove({
    required String fen,
    required int difficulty,
    int thinkTimeMs = 1000,
  }) async {
    if (!_isReady || _stockfish == null) {
      throw StateError('Stockfish not initialized');
    }

    final config = _levelConfig[difficulty] ?? _levelConfig[3]!;
    _currentDifficulty = difficulty;
    _currentConfig = config;
    _currentFen = fen;
    _multipvMoves.clear();
    _bestMoveCompleter = Completer<String>();

    _stockfish!.stdin = 'setoption name UCI_LimitStrength value false';
    _stockfish!.stdin = 'setoption name MultiPV value ${config.multiPv}';
    _stockfish!.stdin = 'position fen $fen';
    _stockfish!.stdin = 'go depth ${config.depth} movetime $thinkTimeMs';

    return _bestMoveCompleter!.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('Stockfish timeout waiting for move'),
    );
  }

  // Picks the move to actually play once the search settles: usually the
  // engine's best line, but with a per-level chance of instead playing one
  // of the weaker MultiPV alternatives — mimicking a human-strength blunder
  // rather than the engine's intentionally hobbled "true" evaluation.
  // Personality biases which alternative gets picked: aggressive bots favor
  // captures (sound or not), defensive bots favor quiet moves.
  String _chooseMove(String? fallback) {
    final ranked = <String>[
      for (var i = 1; i <= _multipvMoves.length; i++)
        if (_multipvMoves[i] != null) _multipvMoves[i]!,
    ];
    if (ranked.isEmpty) return fallback ?? '0000';

    final config = _currentConfig;
    final personality = personalityFor(_currentDifficulty);
    final fen = _currentFen;
    if (ranked.length == 1 || config == null) return ranked.first;

    if (_random.nextDouble() < config.blunderChance) {
      final worseMoves = ranked.sublist(1);
      final pickLimit = _currentDifficulty <= 2
          ? worseMoves.length
          : (_currentDifficulty == 3 ? min(2, worseMoves.length) : 1);
      final pool = worseMoves.take(pickLimit).toList();
      final biased = _pickByPersonality(pool, personality, fen);
      return biased ?? pool[_random.nextInt(pool.length)];
    }

    // Aggressive bots sometimes reach for a sharp near-best capture instead
    // of the technically-best quiet move.
    if (personality == BotPersonality.aggressive && fen != null && _random.nextDouble() < 0.4) {
      final nearBest = ranked.skip(1).take(2).where((m) => _isCapture(fen, m));
      if (nearBest.isNotEmpty) return nearBest.first;
    }

    return ranked.first;
  }

  String? _pickByPersonality(List<String> pool, BotPersonality personality, String? fen) {
    if (fen == null || pool.isEmpty) return null;
    if (personality == BotPersonality.aggressive) {
      final captures = pool.where((m) => _isCapture(fen, m)).toList();
      if (captures.isNotEmpty) return captures[_random.nextInt(captures.length)];
    } else if (personality == BotPersonality.defensive) {
      final quiet = pool.where((m) => !_isCapture(fen, m)).toList();
      if (quiet.isNotEmpty) return quiet[_random.nextInt(quiet.length)];
    }
    return null;
  }

  // True if the destination square of a UCI move is occupied in the given
  // FEN, i.e. the move is a capture. Ignores en passant as a rare edge case.
  bool _isCapture(String fen, String uciMove) {
    if (uciMove.length < 4) return false;
    final rows = fen.split(' ').first.split('/');
    if (rows.length != 8) return false;
    final toFile = uciMove.codeUnitAt(2) - 'a'.codeUnitAt(0);
    final toRank = int.tryParse(uciMove[3]);
    if (toRank == null || toFile < 0 || toFile > 7 || toRank < 1 || toRank > 8) return false;
    final row = rows[8 - toRank];
    var col = 0;
    for (final ch in row.split('')) {
      final digit = int.tryParse(ch);
      if (digit != null) {
        col += digit;
        if (col > toFile) return false;
      } else {
        if (col == toFile) return true;
        col += 1;
      }
    }
    return false;
  }

  // Returns centipawn evaluation from Stockfish (positive = white advantage)
  Future<int> evaluate({required String fen, int depth = 12}) async {
    if (!_isReady || _stockfish == null) return 0;

    final evalCompleter = Completer<int>();
    int? lastScore;

    final sub = _stockfish!.stdout.listen((line) {
      if (line.contains('multipv 1') && line.contains('score cp')) {
        final match = RegExp(r'score cp (-?\d+)').firstMatch(line);
        if (match != null) {
          lastScore = int.tryParse(match.group(1)!);
        }
      }
      if (line.startsWith('bestmove') && !evalCompleter.isCompleted) {
        evalCompleter.complete(lastScore ?? 0);
      }
    });

    _stockfish!.stdin = 'setoption name MultiPV value 1';
    _stockfish!.stdin = 'position fen $fen';
    _stockfish!.stdin = 'go depth $depth';

    final result = await evalCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => 0,
    );
    await sub.cancel();
    return result;
  }

  void dispose() {
    _subscription?.cancel();
    _stockfish?.dispose();
    _stockfish = null;
    _isReady = false;
  }
}
