import 'package:daysteps/src/data/seed.dart';
import 'package:daysteps/src/ui/adult/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'widget_harness.dart';

void main() {
  testWidgets('home lists the boards and a quick timer', (tester) async {
    await pumpDaysteps(
      tester,
      (_) => const HomeScreen(),
      setup: (repo) => seedExampleBoards(repo, symbolExists: (_) => true),
    );
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Bedtime'), findsOneWidget);
    expect(find.text('Homework, then tablet'), findsOneWidget);
    expect(find.text('9 steps'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Show'), findsNWidgets(4));

    await tester.scrollUntilVisible(find.text('Visual timer'), 200);
    expect(find.text('5 min'), findsOneWidget);
  });

  testWidgets('new board asks what kind to make', (tester) async {
    await pumpDaysteps(tester, (_) => const HomeScreen());
    expect(find.text('No boards yet'), findsOneWidget);

    await tester.tap(find.text('New board'));
    await settle(tester);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('First–then board'), findsOneWidget);
  });
}
