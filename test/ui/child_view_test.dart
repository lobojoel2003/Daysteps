import 'package:daysteps/src/data/models.dart';
import 'package:daysteps/src/ui/child/child_mode_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'widget_harness.dart';

void main() {
  late String boardId;

  testWidgets('a child works through a schedule one step at a time', (
    tester,
  ) async {
    final repo = await pumpDaysteps(
      tester,
      (_) => ChildModeScreen(boardId: boardId),
      setup: (repo) async {
        boardId = await repo.createBoard(
          title: 'Morning',
          kind: BoardKind.schedule,
          steps: const [
            StepDraft(
              label: 'Wake up',
              picture: SymbolPicture('mulberry/wake_up'),
            ),
            StepDraft(
              label: 'Breakfast',
              picture: SymbolPicture('mulberry/breakfast'),
            ),
            StepDraft(
              label: 'School bus',
              picture: SymbolPicture('mulberry/school_bus'),
            ),
          ],
        );
      },
    );

    // Now and next, nothing else to tap but the cards and the Done button.
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Wake up'), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);

    await tester.tap(find.bySemanticsLabel('Done'));
    await settle(tester);
    expect(find.text('Wake up'), findsNothing);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('School bus'), findsOneWidget);
    expect(
      await tester.runAsync(
        () => repo.watchProgress(boardId, resetDaily: true).first,
      ),
      1,
    );

    await tester.tap(find.bySemanticsLabel('Done'));
    await settle(tester);
    // On the last step the "Next" slot shows the finish.
    expect(find.text('All done'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Done'));
    await settle(tester);
    expect(find.text('All done!'), findsOneWidget);
    expect(
      await tester.runAsync(
        () => repo.watchProgress(boardId, resetDaily: true).first,
      ),
      3,
    );
  });

  testWidgets('the schedule picks up where the child left off', (tester) async {
    await pumpDaysteps(
      tester,
      (_) => ChildModeScreen(boardId: boardId),
      setup: (repo) async {
        boardId = await repo.createBoard(
          title: 'Day',
          kind: BoardKind.schedule,
          steps: const [
            StepDraft(label: 'One', picture: SymbolPicture('mulberry/wake_up')),
            StepDraft(label: 'Two', picture: SymbolPicture('mulberry/toilet')),
            StepDraft(label: 'Three', picture: SymbolPicture('mulberry/bath')),
          ],
        );
        await repo.setProgress(boardId, 1);
      },
    );
    expect(find.text('One'), findsNothing);
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Three'), findsOneWidget);
  });

  testWidgets('first–then: finish the first card, then the second', (
    tester,
  ) async {
    await pumpDaysteps(
      tester,
      (_) => ChildModeScreen(boardId: boardId),
      setup: (repo) async {
        boardId = await repo.createBoard(
          title: 'Homework, then tablet',
          kind: BoardKind.firstThen,
          steps: const [
            StepDraft(label: 'Homework'),
            StepDraft(label: 'Tablet'),
          ],
        );
      },
    );
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Then'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Done'));
    await settle(tester);
    expect(
      find.bySemanticsLabel('Done'),
      findsOneWidget,
      reason: 'now on the "then" card',
    );

    await tester.tap(find.bySemanticsLabel('Done'));
    await settle(tester);
    expect(find.text('All done!'), findsOneWidget);
  });

  testWidgets('steps with a timer show a visual timer to start', (
    tester,
  ) async {
    await pumpDaysteps(
      tester,
      (_) => ChildModeScreen(boardId: boardId),
      setup: (repo) async {
        boardId = await repo.createBoard(
          title: 'Teeth',
          kind: BoardKind.schedule,
          steps: const [
            StepDraft(label: 'Brush teeth', duration: Duration(minutes: 2)),
          ],
        );
      },
    );
    expect(find.bySemanticsLabel(RegExp('Start timer')), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('Start timer')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.bySemanticsLabel(RegExp('Pause timer')), findsOneWidget);
  });

  testWidgets('leaving the child view needs a grown-up', (tester) async {
    await pumpDaysteps(
      tester,
      (_) => ChildModeScreen(boardId: boardId),
      setup: (repo) async {
        boardId = await repo.createBoard(
          title: 'Day',
          kind: BoardKind.schedule,
          steps: const [StepDraft(label: 'One')],
        );
      },
    );
    final lock = find.bySemanticsLabel(RegExp('For grown-ups'));

    // A quick tap does nothing.
    await tester.tap(lock);
    await settle(tester);
    expect(find.text('For grown-ups'), findsNothing);

    // Holding for two seconds asks a sum.
    final gesture = await tester.startGesture(tester.getCenter(lock));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await settle(tester);
    expect(find.text('For grown-ups'), findsOneWidget);
    expect(find.textContaining('What is'), findsOneWidget);

    // A wrong answer keeps the child view locked.
    await tester.tap(find.text('1'));
    await tester.tap(find.text('1'));
    await settle(tester);
    expect(find.text('Leave child view'), findsNothing);
  });
}
