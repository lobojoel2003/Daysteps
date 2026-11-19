import 'models.dart';
import 'repository.dart';

/// A step of an example board: words, a bundled symbol id and an optional
/// timer in minutes.
typedef _Seed = (String label, String symbol, int? minutes);

const _morning = <_Seed>[
  ('Wake up', 'mulberry/wake_up', null),
  ('Toilet', 'mulberry/toilet', null),
  ('Wash hands', 'mulberry/wash_hands', null),
  ('Get dressed', 'mulberry/get_dressed', null),
  ('Breakfast', 'mulberry/breakfast', null),
  ('Brush teeth', 'mulberry/brush_teeth', 2),
  ('Shoes', 'mulberry/shoes', null),
  ('Coat', 'mulberry/coat', null),
  ('School bus', 'mulberry/school_bus', null),
];

const _afterSchool = <_Seed>[
  ('Snack', 'mulberry/snack', null),
  ('Play', 'mulberry/play', 20),
  ('Tidy up', 'mulberry/tidy_up', 5),
  ('Dinner', 'mulberry/dinner', null),
];

const _bedtime = <_Seed>[
  ('Bath', 'mulberry/bath', null),
  ('Pyjamas', 'mulberry/pyjamas', null),
  ('Brush teeth', 'mulberry/brush_teeth', 2),
  ('Story', 'mulberry/bedtime_story', 10),
  ('Sleep', 'mulberry/sleep', null),
];

const _firstThen = <_Seed>[
  ('Homework', 'mulberry/homework', 15),
  ('Tablet', 'openmoji/tablet', null),
];

/// Creates a few example boards on first launch so the app is useful (and
/// self-explanatory) straight away. Returns the id of the board to show first.
Future<String?> seedExampleBoards(
  DaystepsRepository repo, {
  required bool Function(String symbolId) symbolExists,
}) async {
  List<StepDraft> drafts(List<_Seed> seeds) => [
    for (final (label, symbol, minutes) in seeds)
      StepDraft(
        label: label,
        picture: symbolExists(symbol) ? SymbolPicture(symbol) : null,
        duration: minutes == null ? null : Duration(minutes: minutes),
      ),
  ];

  // Created in reverse: new boards go to the top of the list.
  await repo.createBoard(
    title: 'Homework, then tablet',
    kind: BoardKind.firstThen,
    steps: drafts(_firstThen),
  );
  await repo.createBoard(
    title: 'Bedtime',
    kind: BoardKind.schedule,
    steps: drafts(_bedtime),
  );
  await repo.createBoard(
    title: 'After school',
    kind: BoardKind.schedule,
    steps: drafts(_afterSchool),
  );
  final morning = await repo.createBoard(
    title: 'Morning',
    kind: BoardKind.schedule,
    steps: drafts(_morning),
  );
  return morning;
}
