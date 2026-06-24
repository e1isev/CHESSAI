import '../services/stockfish_service.dart' show BotPersonality;

/// Small per-personality opening books, in UCI move notation. The bot plays
/// straight from these lines while the actual game matches a known
/// continuation, then falls back to the engine the moment the position
/// diverges — mimicking how chess.com bots play memorized lines early on.
const Map<BotPersonality, List<List<String>>> kBotOpeningBooks = {
  BotPersonality.balanced: [
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4'], // Italian Game
    ['d2d4', 'd7d5', 'c2c4', 'e7e6', 'g1f3', 'g8f6'], // Queen's Gambit Declined
  ],
  BotPersonality.aggressive: [
    ['e2e4', 'e7e5', 'f2f4'], // King's Gambit
    ['e2e4', 'c7c5', 'b1c3', 'b8c6', 'g2g3'], // Closed Sicilian
    ['d2d4', 'd7d5', 'c2c4', 'd5c4', 'e2e4'], // Queen's Gambit Accepted, big center
  ],
  BotPersonality.positional: [
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5'], // Ruy López
    ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'b1c3', 'f8b4'], // Nimzo-Indian
  ],
  BotPersonality.defensive: [
    ['e2e4', 'c7c6'], // Caro-Kann
    ['d2d4', 'd7d5', 'g1f3', 'g8f6', 'c1f4'], // London System
    ['e2e4', 'e7e6'], // French Defense
  ],
};
