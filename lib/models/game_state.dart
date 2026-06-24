import 'move_annotation.dart';
import 'opening.dart';

enum GameStatus { idle, playing, checkmate, stalemate, draw, resigned }

enum PlayerColor { white, black }

class GameRecord {
  final int? id;
  final String pgn;
  final String fen;
  final DateTime playedAt;
  final int difficulty;
  final GameStatus result;
  final PlayerColor playerColor;
  final int performanceScore;
  final List<MoveAnnotation> annotations;

  const GameRecord({
    this.id,
    required this.pgn,
    required this.fen,
    required this.playedAt,
    required this.difficulty,
    required this.result,
    required this.playerColor,
    required this.performanceScore,
    required this.annotations,
  });

  GameRecord copyWith({int? id}) => GameRecord(
        id: id ?? this.id,
        pgn: pgn,
        fen: fen,
        playedAt: playedAt,
        difficulty: difficulty,
        result: result,
        playerColor: playerColor,
        performanceScore: performanceScore,
        annotations: annotations,
      );

  Map<String, dynamic> toMap() => {
        'pgn': pgn,
        'fen': fen,
        'played_at': playedAt.toIso8601String(),
        'difficulty': difficulty,
        'result': result.name,
        'player_color': playerColor.name,
        'performance_score': performanceScore,
        'annotations_json': annotations
            .map((a) => a.toJson())
            .toList()
            .toString(),
      };
}

class GameState {
  final String fen;
  final List<String> sanMoves;
  final GameStatus status;
  final PlayerColor playerColor;
  final int difficulty;
  final int effectiveDifficulty;
  final Opening? currentOpening;
  final String? lastCoachingTip;
  final String? aiMoveExplanation;
  final String? blunderWarning;
  final bool isAiThinking;
  final bool isLoadingCoaching;
  final String? selectedSquare;
  final List<String> validMoveSquares;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final String? lastBotQuip;

  const GameState({
    required this.fen,
    this.sanMoves = const [],
    this.status = GameStatus.idle,
    this.playerColor = PlayerColor.white,
    this.difficulty = 3,
    int? effectiveDifficulty,
    this.currentOpening,
    this.lastCoachingTip,
    this.aiMoveExplanation,
    this.blunderWarning,
    this.isAiThinking = false,
    this.isLoadingCoaching = false,
    this.selectedSquare,
    this.validMoveSquares = const [],
    this.lastMoveFrom,
    this.lastMoveTo,
    this.lastBotQuip,
  }) : effectiveDifficulty = effectiveDifficulty ?? difficulty;

  static const initial = GameState(
    fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  );

  GameState copyWith({
    String? fen,
    List<String>? sanMoves,
    GameStatus? status,
    PlayerColor? playerColor,
    int? difficulty,
    int? effectiveDifficulty,
    Opening? currentOpening,
    bool clearOpening = false,
    String? lastCoachingTip,
    bool clearCoachingTip = false,
    String? aiMoveExplanation,
    bool clearAiExplanation = false,
    String? blunderWarning,
    bool clearBlunderWarning = false,
    bool? isAiThinking,
    bool? isLoadingCoaching,
    String? selectedSquare,
    bool clearSelectedSquare = false,
    List<String>? validMoveSquares,
    String? lastMoveFrom,
    bool clearLastMove = false,
    String? lastMoveTo,
    String? lastBotQuip,
    bool clearBotQuip = false,
  }) =>
      GameState(
        fen: fen ?? this.fen,
        sanMoves: sanMoves ?? this.sanMoves,
        status: status ?? this.status,
        playerColor: playerColor ?? this.playerColor,
        difficulty: difficulty ?? this.difficulty,
        effectiveDifficulty: effectiveDifficulty ?? this.effectiveDifficulty,
        currentOpening: clearOpening ? null : (currentOpening ?? this.currentOpening),
        lastCoachingTip: clearCoachingTip ? null : (lastCoachingTip ?? this.lastCoachingTip),
        aiMoveExplanation: clearAiExplanation ? null : (aiMoveExplanation ?? this.aiMoveExplanation),
        blunderWarning: clearBlunderWarning ? null : (blunderWarning ?? this.blunderWarning),
        isAiThinking: isAiThinking ?? this.isAiThinking,
        isLoadingCoaching: isLoadingCoaching ?? this.isLoadingCoaching,
        selectedSquare: clearSelectedSquare ? null : (selectedSquare ?? this.selectedSquare),
        validMoveSquares: validMoveSquares ?? this.validMoveSquares,
        lastMoveFrom: clearLastMove ? null : (lastMoveFrom ?? this.lastMoveFrom),
        lastMoveTo: clearLastMove ? null : (lastMoveTo ?? this.lastMoveTo),
        lastBotQuip: clearBotQuip ? null : (lastBotQuip ?? this.lastBotQuip),
      );
}
