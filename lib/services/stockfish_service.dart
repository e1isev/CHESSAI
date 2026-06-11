import 'dart:async';
import 'package:stockfish_chess_engine/stockfish_chess_engine.dart';

class StockfishService {
  Stockfish? _stockfish;
  StreamSubscription<String>? _subscription;
  Completer<String>? _bestMoveCompleter;
  bool _isReady = false;

  static const Map<int, int> _difficultyToElo = {
    1: 800,
    2: 1100,
    3: 1400,
    4: 1800,
    5: 2400,
  };

  Future<void> init() async {
    _stockfish = Stockfish();
    final readyCompleter = Completer<void>();

    _subscription = _stockfish!.stdout.listen((line) {
      if (line == 'readyok' && !readyCompleter.isCompleted) {
        _isReady = true;
        readyCompleter.complete();
      }
      if (line.startsWith('bestmove')) {
        final parts = line.split(' ');
        if (parts.length >= 2 && _bestMoveCompleter != null && !_bestMoveCompleter!.isCompleted) {
          _bestMoveCompleter!.complete(parts[1]);
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

    final elo = _difficultyToElo[difficulty] ?? 1200;
    _bestMoveCompleter = Completer<String>();

    _stockfish!.stdin = 'setoption name UCI_LimitStrength value true';
    _stockfish!.stdin = 'setoption name UCI_Elo value $elo';
    _stockfish!.stdin = 'position fen $fen';
    _stockfish!.stdin = 'go movetime $thinkTimeMs';

    return _bestMoveCompleter!.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('Stockfish timeout waiting for move'),
    );
  }

  // Returns centipawn evaluation from Stockfish (positive = white advantage)
  Future<int> evaluate({required String fen, int depth = 12}) async {
    if (!_isReady || _stockfish == null) return 0;

    final evalCompleter = Completer<int>();
    int? lastScore;

    final sub = _stockfish!.stdout.listen((line) {
      if (line.contains('score cp')) {
        final match = RegExp(r'score cp (-?\d+)').firstMatch(line);
        if (match != null) {
          lastScore = int.tryParse(match.group(1)!);
        }
      }
      if (line.startsWith('bestmove') && !evalCompleter.isCompleted) {
        evalCompleter.complete(lastScore ?? 0);
      }
    });

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
