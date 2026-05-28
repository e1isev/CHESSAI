import 'package:flutter_test/flutter_test.dart';
import 'package:chess_ai_coach/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ChessCoachApp()));
    await tester.pump();
    expect(find.text('Chess Coach'), findsWidgets);
  });
}
