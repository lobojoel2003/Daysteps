import 'dart:typed_data';

import 'package:daysteps/src/data/models.dart';
import 'package:daysteps/src/data/repository.dart';
import 'package:daysteps/src/data/seed.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late DaystepsRepository repo;
  var now = DateTime(2026, 11, 19, 8);

  setUp(() {
    now = DateTime(2026, 11, 19, 8);
    repo = memoryRepository(clock: () => now);
  });
  tearDown(() => repo.db.close());

  List<String> labels(Board? b) => [for (final s in b!.steps) s.label];

  test('creates a board with steps in order', () async {
    final id = await repo.createBoard(
      title: '  Morning  ',
      kind: BoardKind.schedule,
      steps: const [
        StepDraft(label: 'Wake up', picture: SymbolPicture('mulberry/wake_up')),
        StepDraft(label: 'Brush teeth', duration: Duration(minutes: 2)),
      ],
    );
    final board = await repo.getBoard(id);
    expect(board!.title, 'Morning');
    expect(labels(board), ['Wake up', 'Brush teeth']);
    expect(board.steps.first.picture, const SymbolPicture('mulberry/wake_up'));
    expect(board.steps.last.duration, const Duration(minutes: 2));
  });

  test('empty titles get a friendly default', () async {
    final id = await repo.createBoard(title: '   ', kind: BoardKind.schedule);
    expect((await repo.getBoard(id))!.title, 'My board');
  });

  test('new boards appear first', () async {
    await repo.createBoard(title: 'Old', kind: BoardKind.schedule);
    await repo.createBoard(title: 'New', kind: BoardKind.schedule);
    final boards = await repo.getBoards();
    expect([for (final b in boards) b.title], ['New', 'Old']);
  });

  test('adds, moves and deletes steps', () async {
    final id = await repo.createBoard(
      title: 'Day',
      kind: BoardKind.schedule,
      steps: const [
        StepDraft(label: 'A'),
        StepDraft(label: 'B'),
        StepDraft(label: 'C'),
      ],
    );
    await repo.addStep(id, const StepDraft(label: 'X'), index: 1);
    expect(labels(await repo.getBoard(id)), ['A', 'X', 'B', 'C']);

    await repo.moveStep(id, 0, 3); // A to the end
    expect(labels(await repo.getBoard(id)), ['X', 'B', 'C', 'A']);

    await repo.moveStep(id, 3, 0); // and back
    expect(labels(await repo.getBoard(id)), ['A', 'X', 'B', 'C']);

    final x = (await repo.getBoard(id))!.steps[1];
    await repo.deleteStep(id, x.id);
    expect(labels(await repo.getBoard(id)), ['A', 'B', 'C']);

    final b = (await repo.getBoard(id))!.steps[1];
    await repo.updateStep(
      id,
      b.copyWith(label: 'Bee', duration: const Duration(minutes: 5)),
    );
    final updated = (await repo.getBoard(id))!.steps[1];
    expect(updated.label, 'Bee');
    expect(updated.duration, const Duration(minutes: 5));
  });

  test('duplicates and deletes boards', () async {
    final id = await repo.createBoard(
      title: 'Bedtime',
      kind: BoardKind.schedule,
      steps: const [
        StepDraft(label: 'Bath'),
        StepDraft(label: 'Sleep'),
      ],
    );
    final copy = await repo.duplicateBoard(id);
    expect((await repo.getBoard(copy!))!.title, 'Bedtime (copy)');
    expect(labels(await repo.getBoard(copy)), ['Bath', 'Sleep']);

    await repo.setProgress(id, 1);
    await repo.deleteBoard(id);
    expect(await repo.getBoard(id), isNull);
    expect(await repo.getBoard(copy), isNotNull);
  });

  test('watchBoard emits changes', () async {
    final id = await repo.createBoard(title: 'Live', kind: BoardKind.schedule);
    final emitted = <List<String>>[];
    final sub = repo.watchBoard(id).listen((b) => emitted.add(labels(b)));
    await pumpEventQueue();
    await repo.addStep(id, const StepDraft(label: 'One'));
    await pumpEventQueue();
    await sub.cancel();
    expect(emitted.first, isEmpty);
    expect(emitted.last, ['One']);
  });

  test('progress resets on a new day when asked to', () async {
    final id = await repo.createBoard(title: 'Day', kind: BoardKind.schedule);
    await repo.setProgress(id, 3);
    expect(await repo.watchProgress(id, resetDaily: true).first, 3);

    now = now.add(const Duration(days: 1));
    expect(await repo.watchProgress(id, resetDaily: true).first, 0);
    expect(await repo.watchProgress(id, resetDaily: false).first, 3);
  });

  test('deleting a photo keeps the cards that used it', () async {
    final pictureId = await repo.addPicture(
      source: PictureSource.photo,
      label: 'Grandma',
      bytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/jpeg',
    );
    final id = await repo.createBoard(
      title: 'Visit',
      kind: BoardKind.schedule,
      steps: [StepDraft(label: 'Grandma', picture: StoredPicture(pictureId))],
    );
    expect(await repo.countPictureUses(pictureId), 1);

    await repo.deletePicture(pictureId);
    final step = (await repo.getBoard(id))!.steps.single;
    expect(step.label, 'Grandma');
    expect(step.picture, isNull);
    expect(await repo.getPicture(pictureId), isNull);
  });

  test('settings are saved and updated', () async {
    expect(await repo.getSettings(), const AppSettings());
    await repo.updateSettings(
      (s) => s.copyWith(calmMotion: true, activeBoardId: 'x'),
    );
    final saved = await repo.getSettings();
    expect(saved.calmMotion, isTrue);
    expect(saved.activeBoardId, 'x');
  });

  test('seeds example boards with bundled symbols', () async {
    final first = await seedExampleBoards(repo, symbolExists: (_) => true);
    final boards = await repo.getBoards();
    expect(boards.first.id, first);
    expect(boards.first.title, 'Morning');
    expect(
      boards.map((b) => b.title),
      containsAll([
        'Morning',
        'After school',
        'Bedtime',
        'Homework, then tablet',
      ]),
    );
    expect(boards.every((b) => b.isPlayable), isTrue);
  });
}
