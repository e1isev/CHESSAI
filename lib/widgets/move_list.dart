import 'package:flutter/material.dart';

class MoveList extends StatelessWidget {
  final List<String> moves;
  final int? highlightedIndex;

  const MoveList({super.key, required this.moves, this.highlightedIndex});

  @override
  Widget build(BuildContext context) {
    if (moves.isEmpty) {
      return const Center(
        child: Text('No moves yet', style: TextStyle(color: Colors.white38, fontSize: 12)),
      );
    }

    final pairs = <(int, String, String?)>[];
    for (int i = 0; i < moves.length; i += 2) {
      pairs.add((i ~/ 2 + 1, moves[i], i + 1 < moves.length ? moves[i + 1] : null));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: pairs.map((pair) {
          final (num, white, black) = pair;
          final whiteIdx = (pair.$1 - 1) * 2;
          final blackIdx = whiteIdx + 1;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$num.',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(width: 2),
                _MoveChip(move: white, isHighlighted: highlightedIndex == whiteIdx),
                if (black != null) ...[
                  const SizedBox(width: 2),
                  _MoveChip(move: black, isHighlighted: highlightedIndex == blackIdx),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  final String move;
  final bool isHighlighted;

  const _MoveChip({required this.move, required this.isHighlighted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isHighlighted
            ? const Color(0xFFF4B942).withValues(alpha: 0.25)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: isHighlighted
            ? Border.all(color: const Color(0xFFF4B942).withValues(alpha: 0.5))
            : null,
      ),
      child: Text(
        move,
        style: TextStyle(
          color: isHighlighted ? const Color(0xFFF4B942) : Colors.white70,
          fontSize: 12,
          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
