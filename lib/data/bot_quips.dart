import '../services/stockfish_service.dart' show BotPersonality;

/// Short personality-flavored lines the bot "says" after notable moments —
/// mirroring the lightweight banter chess.com bots show after captures and
/// checks. Picked at random so the same line doesn't repeat every game.
enum BotMoment { freeCapture, capture, check }

const Map<BotPersonality, Map<BotMoment, List<String>>> kBotQuips = {
  BotPersonality.aggressive: {
    BotMoment.freeCapture: [
      "Free piece? Don't mind if I do.",
      "Leave that lying around again, please.",
      "Thanks for the gift.",
    ],
    BotMoment.capture: [
      "Crunch.",
      "Trading up, as usual.",
    ],
    BotMoment.check: [
      "Check. Hope you saw that coming.",
      "King's looking a little exposed.",
    ],
  },
  BotPersonality.defensive: {
    BotMoment.freeCapture: [
      "I'll take that, thank you.",
      "Never say no to free material.",
    ],
    BotMoment.capture: [
      "Solid trade.",
      "Keeping things tidy.",
    ],
    BotMoment.check: [
      "Check — better tuck that king away.",
    ],
  },
  BotPersonality.positional: {
    BotMoment.freeCapture: [
      "An undefended piece is a gift I won't refuse.",
      "That one was just sitting there.",
    ],
    BotMoment.capture: [
      "A small but useful trade.",
    ],
    BotMoment.check: [
      "Check. Let's see how you respond.",
    ],
  },
  BotPersonality.balanced: {
    BotMoment.freeCapture: [
      "I'll take that — free pieces don't last long with me.",
      "Can't leave that hanging.",
    ],
    BotMoment.capture: [
      "Taking that.",
    ],
    BotMoment.check: [
      "Check.",
    ],
  },
};
