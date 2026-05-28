enum AnnotationType { tip, blunder, brilliant, opening, tactical }

class MoveAnnotation {
  final int moveIndex;
  final String move;
  final String comment;
  final AnnotationType type;
  final String? betterMove;
  final String? tacticalPattern;

  const MoveAnnotation({
    required this.moveIndex,
    required this.move,
    required this.comment,
    required this.type,
    this.betterMove,
    this.tacticalPattern,
  });

  Map<String, dynamic> toJson() => {
        'moveIndex': moveIndex,
        'move': move,
        'comment': comment,
        'type': type.name,
        'betterMove': betterMove,
        'tacticalPattern': tacticalPattern,
      };

  factory MoveAnnotation.fromJson(Map<String, dynamic> json) =>
      MoveAnnotation(
        moveIndex: json['moveIndex'] as int,
        move: json['move'] as String,
        comment: json['comment'] as String,
        type: AnnotationType.values.byName(json['type'] as String),
        betterMove: json['betterMove'] as String?,
        tacticalPattern: json['tacticalPattern'] as String?,
      );
}
