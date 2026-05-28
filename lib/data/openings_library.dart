import '../models/opening.dart';

const List<Opening> kOpeningsLibrary = [
  Opening(
    name: 'Italian Game',
    eco: 'C50',
    moves: ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4'],
    description:
        'One of the oldest and most classical openings. White develops quickly toward the center and aims to control key squares.',
    plan:
        'Develop pieces naturally, castle kingside, and look for the f4-f5 pawn break or central play with d3-d4.',
    tags: ['classical', 'beginner-friendly', 'open'],
  ),
  Opening(
    name: "Ruy López (Spanish Game)",
    eco: 'C60',
    moves: ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5'],
    description:
        'A sophisticated opening used by the world\'s best players. White pins the knight defending e5 to put long-term pressure on Black\'s center.',
    plan:
        'Play d4 to gain central control. The Spanish is a positional opening — think long-term piece activity and pawn structure.',
    tags: ['positional', 'advanced', 'open'],
  ),
  Opening(
    name: 'Sicilian Defense',
    eco: 'B20',
    moves: ['e4', 'c5'],
    description:
        'The most popular and combative response to 1.e4. Black fights for the d4 square asymmetrically, leading to rich, complex positions.',
    plan:
        'Black typically plays ...d6, ...Nf6, ...a6 (Najdorf) or ...Nc6 to fight for the d4 square. Expect sharp, tactical play.',
    tags: ['sharp', 'counter-attacking', 'semi-open'],
  ),
  Opening(
    name: "King's Gambit",
    eco: 'C30',
    moves: ['e4', 'e5', 'f4'],
    description:
        'An aggressive, romantic opening where White sacrifices the f-pawn for rapid development and a strong center.',
    plan:
        'Accept the gambit with ...exf4 or decline with ...Bc5. White aims to open the f-file and attack quickly with Nf3, d4, and Bc4.',
    tags: ['aggressive', 'gambit', 'open'],
  ),
  Opening(
    name: 'London System',
    eco: 'D02',
    moves: ['d4', 'd5', 'Nf3', 'Nf6', 'Bf4'],
    description:
        'A solid, system-like opening for White. Very reliable — White sets up the same structure regardless of what Black plays.',
    plan:
        'Complete development with e3, Nbd2, Bd3. The bishop on f4 is very active. Later play c4 to challenge Black\'s center or build with h3, g4.',
    tags: ['solid', 'system', 'beginner-friendly', 'closed'],
  ),
  Opening(
    name: "Queen's Gambit",
    eco: 'D06',
    moves: ['d4', 'd5', 'c4'],
    description:
        'White offers a pawn to gain central control. If Black takes (Accepted), White gets a strong center. If declined, a positional battle follows.',
    plan:
        'If Black accepts with ...dxc4, play e4 to build a big center. If declined with ...e6, play Nc3, Nf3, and Bg5 for long-term pressure.',
    tags: ['positional', 'classical', 'closed'],
  ),
  Opening(
    name: "King's Indian Defense",
    eco: 'E60',
    moves: ['d4', 'Nf6', 'c4', 'g6', 'Nc3', 'Bg7', 'e4', 'd6'],
    description:
        'A hyper-modern defense where Black lets White take the center, then counterattacks with ...e5 or ...c5.',
    plan:
        'Black castles kingside and launches a fierce kingside attack with ...e5, ...Nd7, ...f5. Very dynamic and double-edged.',
    tags: ['dynamic', 'counter-attacking', 'hypermodern'],
  ),
  Opening(
    name: 'French Defense',
    eco: 'C00',
    moves: ['e4', 'e6', 'd4', 'd5'],
    description:
        'Black builds a solid pawn chain with ...e6 and ...d5. Very solid but can be slightly passive on the queenside.',
    plan:
        'Black plays ...c5 to attack White\'s pawn chain. The light-squared bishop is often a problem piece — Black should activate it with ...b6 or ...Bd7-e8-h5.',
    tags: ['solid', 'defensive', 'semi-open'],
  ),
  Opening(
    name: 'Caro-Kann Defense',
    eco: 'B10',
    moves: ['e4', 'c6', 'd4', 'd5'],
    description:
        'A solid and reliable defense to 1.e4. Black challenges the center with ...c6 and ...d5 without weakening the kingside.',
    plan:
        'After ...dxe4 and Nxe4, Black plays ...Nd7 or ...Bf5 to develop actively. The position is solid — Black usually gets a good endgame.',
    tags: ['solid', 'defensive', 'semi-open'],
  ),
  Opening(
    name: "Nimzo-Indian Defense",
    eco: 'E20',
    moves: ['d4', 'Nf6', 'c4', 'e6', 'Nc3', 'Bb4'],
    description:
        'A highly sophisticated defense. Black pins White\'s knight and fights for central control without placing a pawn in the center early.',
    plan:
        'Black will double White\'s pawns with ...Bxc3. Fight for the e4 square with ...d5 and ...Ne4. Excellent for strategic players.',
    tags: ['strategic', 'hypermodern', 'advanced'],
  ),
  Opening(
    name: 'Pirc Defense',
    eco: 'B07',
    moves: ['e4', 'd6', 'd4', 'Nf6', 'Nc3', 'g6'],
    description:
        'A hypermodern defense where Black fianchettos and lets White build a large center before counterattacking.',
    plan:
        'Black develops with ...Bg7 and ...0-0, then counterattacks with ...c5 or ...e5 to undermine White\'s center.',
    tags: ['hypermodern', 'flexible', 'counter-attacking'],
  ),
  Opening(
    name: "Scotch Game",
    eco: 'C45',
    moves: ['e4', 'e5', 'Nf3', 'Nc6', 'd4', 'exd4', 'Nxd4'],
    description:
        'White immediately opens the center on move 3. Very direct — White gets an open game quickly and active piece play.',
    plan:
        'After Nxd4, develop with Nc3 and Bc4. White has a slight space advantage. Attack with f4-f5 or a queenside expansion.',
    tags: ['direct', 'open', 'classical'],
  ),
];

Opening? detectOpening(List<String> moves) {
  Opening? best;
  int bestLen = 0;

  for (final opening in kOpeningsLibrary) {
    final len = opening.moves.length;
    if (moves.length >= len) {
      bool match = true;
      for (int i = 0; i < len; i++) {
        if (moves[i] != opening.moves[i]) {
          match = false;
          break;
        }
      }
      if (match && len > bestLen) {
        best = opening;
        bestLen = len;
      }
    }
  }
  return best;
}
