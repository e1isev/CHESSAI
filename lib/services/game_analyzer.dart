import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/game_state.dart';
import '../models/move_annotation.dart';

class GameAnalyzer {
  static Database? _db;

  static Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'chess_coach.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE games (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pgn TEXT NOT NULL,
            fen TEXT NOT NULL,
            played_at TEXT NOT NULL,
            difficulty INTEGER NOT NULL,
            result TEXT NOT NULL,
            player_color TEXT NOT NULL,
            performance_score INTEGER NOT NULL,
            annotations_json TEXT
          )
        ''');
      },
    );
    return _db!;
  }

  Future<int> saveGame(GameRecord record) async {
    final db = await _getDb();
    return db.insert('games', record.toMap());
  }

  Future<List<GameRecord>> loadGames({int limit = 50}) async {
    final db = await _getDb();
    final rows = await db.query(
      'games',
      orderBy: 'played_at DESC',
      limit: limit,
    );
    return rows.map(_rowToRecord).toList();
  }

  Future<void> deleteGame(int id) async {
    final db = await _getDb();
    await db.delete('games', where: 'id = ?', whereArgs: [id]);
  }

  GameRecord _rowToRecord(Map<String, dynamic> row) {
    return GameRecord(
      id: row['id'] as int,
      pgn: row['pgn'] as String,
      fen: row['fen'] as String,
      playedAt: DateTime.parse(row['played_at'] as String),
      difficulty: row['difficulty'] as int,
      result: GameStatus.values.byName(row['result'] as String),
      playerColor: PlayerColor.values.byName(row['player_color'] as String),
      performanceScore: row['performance_score'] as int,
      annotations: const [],
    );
  }

  // Estimate performance score from annotations
  static int computeScore(List<MoveAnnotation> annotations, int totalMoves) {
    if (totalMoves == 0) return 50;
    int penalties = 0;
    for (final a in annotations) {
      if (a.type == AnnotationType.blunder) penalties += 20;
      if (a.type == AnnotationType.tip) penalties += 5;
    }
    final score = 100 - (penalties * 100 ~/ (totalMoves * 5));
    return score.clamp(0, 100);
  }
}
