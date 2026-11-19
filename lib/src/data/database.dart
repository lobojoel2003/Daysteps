import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'models.dart';

part 'database.g.dart';

/// A schedule or first–then board that an adult builds and a child follows.
@DataClassName('BoardRow')
class Boards extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 80)();
  IntColumn get kind => intEnum<BoardKind>()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One picture card on a board. For first–then boards, position 0 is "first"
/// and position 1 is "then".
@DataClassName('StepRow')
class BoardSteps extends Table {
  TextColumn get id => text()();
  TextColumn get boardId =>
      text().references(Boards, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get label => text().withLength(max: 80)();

  /// A [PictureRef] in its string form, or null for a words-only card.
  TextColumn get picture => text().nullable()();

  /// Optional visual-timer length for this step.
  IntColumn get durationSeconds => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Pictures that are not bundled with the app: the family's own photos and
/// optional ARASAAC downloads. Stored as blobs so the same code works on
/// Android (SQLite file) and the web (SQLite in OPFS / IndexedDB).
@DataClassName('PictureRow')
class Pictures extends Table {
  TextColumn get id => text()();
  IntColumn get source => intEnum<PictureSource>()();
  TextColumn get label => text()();
  BlobColumn get bytes => blob()();
  TextColumn get mimeType => text()();
  TextColumn get attribution => text().nullable()();

  /// The ARASAAC pictogram id, used to avoid downloading the same one twice.
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// How far the child has got through a board today.
@DataClassName('ProgressRow')
class BoardProgress extends Table {
  TextColumn get boardId =>
      text().references(Boards, #id, onDelete: KeyAction.cascade)();
  IntColumn get doneCount => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {boardId};
}

/// Simple key/value store for [AppSettings].
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [Boards, BoardSteps, Pictures, BoardProgress, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the on-device database (SQLite file on Android, WASM SQLite with
  /// OPFS/IndexedDB persistence on the web).
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'daysteps',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await m.createIndex(
        Index(
          'board_steps_board',
          'CREATE INDEX board_steps_board ON board_steps (board_id, position)',
        ),
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
