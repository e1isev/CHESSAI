import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiCoachingService {
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  final String apiKey;

  GeminiCoachingService({required this.apiKey});

  Future<String?> getMidGameTip({
    required String fen,
    required String lastMove,
    required List<String> moveHistory,
  }) async {
    final pgn = moveHistory.join(' ');
    final prompt =
        'You are a friendly chess coach helping a beginner. '
        'The current position in FEN is: $fen. '
        'The player just moved $lastMove. '
        'Move history: $pgn. '
        'In 1-2 sentences, give a helpful coaching tip about the position. '
        'If they missed something better, mention it gently. '
        'Be encouraging and specific.';
    return _callGemini(prompt);
  }

  Future<String?> getAiMoveExplanation({
    required String move,
    required String fen,
    required List<String> moveHistory,
  }) async {
    final prompt =
        'You are a chess AI explaining your move to a beginner student. '
        'You just played $move in this position (FEN: $fen). '
        'In 1-2 friendly sentences, explain WHY you made this move — '
        'what strategic or tactical idea it achieves. '
        'Be clear and educational, avoid jargon where possible.';
    return _callGemini(prompt);
  }

  Future<String?> getBlunderWarning({
    required String proposedMove,
    required String fen,
    required int evalBefore,
    required int evalAfter,
  }) async {
    final drop = evalBefore - evalAfter;
    if (drop < 150) return null;
    final prompt =
        'You are a chess coach. A beginner is about to play $proposedMove '
        'in position FEN: $fen. This move loses about ${(drop / 100).toStringAsFixed(1)} '
        'pawns of advantage. In one gentle sentence, warn them this might '
        'be a mistake and encourage them to look for a better move. '
        'Do not reveal the better move specifically.';
    return _callGemini(prompt);
  }

  Future<PostGameAnalysis?> analyzeGame({
    required String pgn,
    required List<String> moveHistory,
  }) async {
    final prompt =
        'Analyze this chess game PGN: $pgn\n\n'
        'Respond in valid JSON with this exact structure:\n'
        '{\n'
        '  "score": <number 0-100>,\n'
        '  "summary": "<2-3 sentence encouraging summary>",\n'
        '  "mistakes": [\n'
        '    {"move": "<move>", "comment": "<what went wrong>", "better": "<better move or idea>"},\n'
        '    ...\n'
        '  ],\n'
        '  "bestMove": {"move": "<move>", "comment": "<why it was great>"},\n'
        '  "advice": "<one key piece of advice for improvement>"\n'
        '}\n\n'
        'Limit to 3 mistakes. Be encouraging and educational.';

    final raw = await _callGemini(prompt, maxTokens: 800);
    if (raw == null) return null;

    try {
      final jsonStr = _extractJson(raw);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return PostGameAnalysis.fromJson(data);
    } catch (_) {
      return PostGameAnalysis(score: 50, summary: raw, mistakes: const [], advice: '');
    }
  }

  Future<String?> _callGemini(String prompt, {int maxTokens = 300}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {'maxOutputTokens': maxTokens},
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String?;
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1) return text;
    return text.substring(start, end + 1);
  }
}

class PostGameAnalysis {
  final int score;
  final String summary;
  final List<MistakeEntry> mistakes;
  final BestMoveEntry? bestMove;
  final String advice;

  const PostGameAnalysis({
    required this.score,
    required this.summary,
    required this.mistakes,
    this.bestMove,
    required this.advice,
  });

  factory PostGameAnalysis.fromJson(Map<String, dynamic> json) {
    final mistakesRaw = json['mistakes'] as List<dynamic>? ?? [];
    return PostGameAnalysis(
      score: (json['score'] as num?)?.toInt() ?? 50,
      summary: json['summary'] as String? ?? '',
      mistakes: mistakesRaw
          .map((m) => MistakeEntry.fromJson(m as Map<String, dynamic>))
          .toList(),
      bestMove: json['bestMove'] != null
          ? BestMoveEntry.fromJson(json['bestMove'] as Map<String, dynamic>)
          : null,
      advice: json['advice'] as String? ?? '',
    );
  }
}

class MistakeEntry {
  final String move;
  final String comment;
  final String better;

  const MistakeEntry({required this.move, required this.comment, required this.better});

  factory MistakeEntry.fromJson(Map<String, dynamic> json) => MistakeEntry(
        move: json['move'] as String? ?? '',
        comment: json['comment'] as String? ?? '',
        better: json['better'] as String? ?? '',
      );
}

class BestMoveEntry {
  final String move;
  final String comment;

  const BestMoveEntry({required this.move, required this.comment});

  factory BestMoveEntry.fromJson(Map<String, dynamic> json) => BestMoveEntry(
        move: json['move'] as String? ?? '',
        comment: json['comment'] as String? ?? '',
      );
}
