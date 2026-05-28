import 'package:flutter/material.dart';
import '../models/game_state.dart';

const _lightSquare = Color(0xFFE8CFA9);
const _darkSquare = Color(0xFF8B5E3C);
const _selectedHighlight = Color(0x8832CD32);
const _validMoveHighlight = Color(0x6632CD32);
const _lastMoveHighlight = Color(0x66F4B942);

const _pieceSymbols = {
  'wK': '♔', 'wQ': '♕', 'wR': '♖', 'wB': '♗', 'wN': '♘', 'wP': '♙',
  'bK': '♚', 'bQ': '♛', 'bR': '♜', 'bB': '♝', 'bN': '♞', 'bP': '♟',
};

class ChessBoard extends StatelessWidget {
  final GameState gameState;
  final void Function(String square) onSquareTap;

  const ChessBoard({
    super.key,
    required this.gameState,
    required this.onSquareTap,
  });

  @override
  Widget build(BuildContext context) {
    final pieces = _parseFen(gameState.fen);
    final flipped = gameState.playerColor == PlayerColor.black;

    return AspectRatio(
      aspectRatio: 1,
      child: Column(
        children: List.generate(8, (rowIdx) {
          final rank = flipped ? rowIdx : 7 - rowIdx;
          return Expanded(
            child: Row(
              children: List.generate(8, (colIdx) {
                final file = flipped ? 7 - colIdx : colIdx;
                final square = _squareName(file, rank);
                final piece = pieces[square];
                final isLight = (file + rank) % 2 == 1;
                final isSelected = gameState.selectedSquare == square;
                final isValidMove = gameState.validMoveSquares.contains(square);
                final isLastFrom = gameState.lastMoveFrom == square;
                final isLastTo = gameState.lastMoveTo == square;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onSquareTap(square),
                    child: _SquareWidget(
                      isLight: isLight,
                      isSelected: isSelected,
                      isValidMove: isValidMove,
                      isLastMoveSquare: isLastFrom || isLastTo,
                      piece: piece,
                      label: _squareLabel(file, rank, flipped, colIdx, rowIdx),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  String? _squareLabel(int file, int rank, bool flipped, int col, int row) => null;

  String _squareName(int file, int rank) {
    const files = 'abcdefgh';
    return '${files[file]}${rank + 1}';
  }

  Map<String, String> _parseFen(String fen) {
    final parts = fen.split(' ');
    final board = parts[0];
    final rows = board.split('/');
    final result = <String, String>{};
    const files = 'abcdefgh';

    for (int rankIdx = 0; rankIdx < 8; rankIdx++) {
      final rank = 7 - rankIdx;
      final row = rows[rankIdx];
      int file = 0;
      for (final ch in row.runes) {
        final c = String.fromCharCode(ch);
        if (RegExp(r'\d').hasMatch(c)) {
          file += int.parse(c);
        } else {
          final color = c == c.toUpperCase() ? 'w' : 'b';
          final type = c.toUpperCase();
          result['${files[file]}${rank + 1}'] = '$color$type';
          file++;
        }
      }
    }
    return result;
  }
}

class _SquareWidget extends StatelessWidget {
  final bool isLight;
  final bool isSelected;
  final bool isValidMove;
  final bool isLastMoveSquare;
  final String? piece;
  final String? label;

  const _SquareWidget({
    required this.isLight,
    required this.isSelected,
    required this.isValidMove,
    required this.isLastMoveSquare,
    this.piece,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final base = isLight ? _lightSquare : _darkSquare;
    Color bg = base;
    if (isLastMoveSquare) bg = Color.alphaBlend(_lastMoveHighlight, base);
    if (isSelected) bg = Color.alphaBlend(_selectedHighlight, base);

    return Container(
      color: bg,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isValidMove)
            piece != null
                ? Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _validMoveHighlight, width: 3),
                    ),
                  )
                : Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _validMoveHighlight,
                    ),
                  ),
          if (piece != null)
            FittedBox(
              fit: BoxFit.contain,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Text(
                  _pieceSymbols[piece] ?? '',
                  style: TextStyle(
                    fontSize: 36,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 2,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
