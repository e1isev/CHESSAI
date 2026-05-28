import '../data/openings_library.dart';
import '../models/opening.dart';

class OpeningDetector {
  Opening? _currentOpening;
  int _lastCheckedLength = 0;

  Opening? update(List<String> sanMoves) {
    if (sanMoves.length == _lastCheckedLength) return _currentOpening;
    _lastCheckedLength = sanMoves.length;

    // Only check for openings in the first 15 moves
    if (sanMoves.length > 15) return _currentOpening;

    final detected = detectOpening(sanMoves);
    if (detected != null && detected.name != _currentOpening?.name) {
      _currentOpening = detected;
    }
    return _currentOpening;
  }

  void reset() {
    _currentOpening = null;
    _lastCheckedLength = 0;
  }
}
