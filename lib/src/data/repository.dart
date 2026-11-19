import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';
import 'models.dart';

/// All reads and writes the app makes. Widgets never talk to drift directly.
class DaystepsRepository {
  DaystepsRepository(this.db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  String newId() => _uuid.v4();

  // ---------------------------------------------------------------------------
  // Boards
  // ---------------------------------------------------------------------------

  /// All boards with their steps, in the adult's chosen order.
  Stream<List<Board>> watchBoards() =>
      _onTables({db.boards, db.boardSteps}, getBoards);

  /// One board with its steps, or null once it has been deleted.
  Stream<Board?> watchBoard(String id) {
    return _onTables({db.boards, db.boardSteps}, () => getBoard(id));
  }

  Future<Board?> getBoard(String id) async {
    final row = await (db.select(
      db.boards,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final steps =
        await (db.select(db.boardSteps)
              ..where((s) => s.boardId.equals(id))
              ..orderBy([(s) => OrderingTerm.asc(s.position)]))
            .get();
    return _toBoard(row, steps);
  }

  Future<List<Board>> getBoards() async {
    final boards =
        await (db.select(db.boards)..orderBy([
              (b) => OrderingTerm.asc(b.sortOrder),
              (b) => OrderingTerm.desc(b.updatedAt),
            ]))
            .get();
    final steps = await (db.select(
      db.boardSteps,
    )..orderBy([(s) => OrderingTerm.asc(s.position)])).get();
    final byBoard = groupBy(steps, (StepRow s) => s.boardId);
    return [for (final b in boards) _toBoard(b, byBoard[b.id] ?? const [])];
  }

  /// Creates a board and returns its id.
  Future<String> createBoard({
    required String title,
    required BoardKind kind,
    List<StepDraft> steps = const [],
  }) async {
    final id = newId();
    final now = _clock();
    await db.transaction(() async {
      final minOrder = await _minSortOrder();
      await db
          .into(db.boards)
          .insert(
            BoardsCompanion.insert(
              id: id,
              title: _cleanTitle(title),
              kind: kind,
              sortOrder: Value(minOrder - 1),
              createdAt: now,
              updatedAt: now,
            ),
          );
      for (final (i, draft) in steps.indexed) {
        await db.into(db.boardSteps).insert(_stepCompanion(id, i, draft));
      }
    });
    return id;
  }

  Future<void> renameBoard(String id, String title) async {
    await (db.update(db.boards)..where((b) => b.id.equals(id))).write(
      BoardsCompanion(
        title: Value(_cleanTitle(title)),
        updatedAt: Value(_clock()),
      ),
    );
  }

  Future<void> deleteBoard(String id) async {
    await db.transaction(() async {
      await (db.delete(db.boardSteps)..where((s) => s.boardId.equals(id))).go();
      await (db.delete(
        db.boardProgress,
      )..where((p) => p.boardId.equals(id))).go();
      await (db.delete(db.boards)..where((b) => b.id.equals(id))).go();
    });
  }

  /// Copies a board (steps included) and returns the new id.
  Future<String?> duplicateBoard(String id, {String? title}) async {
    final board = await getBoard(id);
    if (board == null) return null;
    return createBoard(
      title: title ?? _copyTitle(board.title),
      kind: board.kind,
      steps: [
        for (final s in board.steps)
          StepDraft(label: s.label, picture: s.picture, duration: s.duration),
      ],
    );
  }

  /// Saves the adult's new board order (ids from top to bottom).
  Future<void> reorderBoards(List<String> orderedIds) async {
    await db.transaction(() async {
      for (final (i, id) in orderedIds.indexed) {
        await (db.update(db.boards)..where((b) => b.id.equals(id))).write(
          BoardsCompanion(sortOrder: Value(i)),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Steps
  // ---------------------------------------------------------------------------

  /// Adds a step at [index] (or the end) and returns its id.
  Future<String> addStep(String boardId, StepDraft draft, {int? index}) async {
    late final String stepId;
    await db.transaction(() async {
      final steps = await _stepRows(boardId);
      final at = (index ?? steps.length).clamp(0, steps.length);
      final companion = _stepCompanion(boardId, at, draft);
      stepId = companion.id.value;
      // Shift the following steps down.
      for (final s in steps.skip(at)) {
        await (db.update(db.boardSteps)..where((r) => r.id.equals(s.id))).write(
          BoardStepsCompanion(position: Value(s.position + 1)),
        );
      }
      await db.into(db.boardSteps).insert(companion);
      await _touch(boardId);
    });
    return stepId;
  }

  Future<void> updateStep(String boardId, BoardStep step) async {
    await db.transaction(() async {
      await (db.update(
        db.boardSteps,
      )..where((s) => s.id.equals(step.id))).write(
        BoardStepsCompanion(
          label: Value(_cleanLabel(step.label)),
          picture: Value(step.picture?.encoded),
          durationSeconds: Value(step.duration?.inSeconds),
        ),
      );
      await _touch(boardId);
    });
  }

  Future<void> deleteStep(String boardId, String stepId) async {
    await db.transaction(() async {
      await (db.delete(db.boardSteps)..where((s) => s.id.equals(stepId))).go();
      await _renumber(boardId);
      await _touch(boardId);
    });
  }

  /// Moves the step at [oldIndex] so that it ends up at [newIndex] (the
  /// index after removal, as [ReorderableListView.onReorderItem] reports).
  Future<void> moveStep(String boardId, int oldIndex, int newIndex) async {
    await db.transaction(() async {
      final steps = (await _stepRows(boardId)).toList();
      if (oldIndex < 0 || oldIndex >= steps.length) return;
      final moved = steps.removeAt(oldIndex);
      steps.insert(newIndex.clamp(0, steps.length), moved);
      await _writePositions(steps.map((s) => s.id).toList());
      await _touch(boardId);
    });
  }

  /// Sets both cards of a first–then board at once.
  Future<void> setFirstThen(
    String boardId, {
    required StepDraft first,
    required StepDraft then,
  }) async {
    await db.transaction(() async {
      await (db.delete(
        db.boardSteps,
      )..where((s) => s.boardId.equals(boardId))).go();
      await db.into(db.boardSteps).insert(_stepCompanion(boardId, 0, first));
      await db.into(db.boardSteps).insert(_stepCompanion(boardId, 1, then));
      await _touch(boardId);
    });
  }

  // ---------------------------------------------------------------------------
  // Pictures (photos and ARASAAC downloads)
  // ---------------------------------------------------------------------------

  Stream<List<PictureRow>> watchPictures(PictureSource source) {
    return (db.select(db.pictures)
          ..where((p) => p.source.equalsValue(source))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  Future<PictureRow?> getPicture(String id) {
    return (db.select(
      db.pictures,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<PictureRow?> findByRemoteId(PictureSource source, String remoteId) {
    return (db.select(db.pictures)
          ..where(
            (p) => p.source.equalsValue(source) & p.remoteId.equals(remoteId),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<String> addPicture({
    required PictureSource source,
    required String label,
    required Uint8List bytes,
    required String mimeType,
    String? attribution,
    String? remoteId,
    String? id,
  }) async {
    final pictureId = id ?? newId();
    await db
        .into(db.pictures)
        .insert(
          PicturesCompanion.insert(
            id: pictureId,
            source: source,
            label: _cleanLabel(label),
            bytes: bytes,
            mimeType: mimeType,
            attribution: Value(attribution),
            remoteId: Value(remoteId),
            createdAt: _clock(),
          ),
          mode: InsertMode.insertOrReplace,
        );
    return pictureId;
  }

  Future<void> renamePicture(String id, String label) async {
    await (db.update(db.pictures)..where((p) => p.id.equals(id))).write(
      PicturesCompanion(label: Value(_cleanLabel(label))),
    );
  }

  /// Deletes a picture. Cards that used it keep their words.
  Future<void> deletePicture(String id) async {
    final ref = StoredPicture(id).encoded;
    await db.transaction(() async {
      await (db.update(db.boardSteps)..where((s) => s.picture.equals(ref)))
          .write(const BoardStepsCompanion(picture: Value(null)));
      await (db.delete(db.pictures)..where((p) => p.id.equals(id))).go();
    });
  }

  /// How many cards use a picture (shown before deleting it).
  Future<int> countPictureUses(String id) async {
    final ref = StoredPicture(id).encoded;
    final count = db.boardSteps.id.count();
    final query = db.selectOnly(db.boardSteps)
      ..addColumns([count])
      ..where(db.boardSteps.picture.equals(ref));
    return (await query.getSingle()).read(count) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Child progress
  // ---------------------------------------------------------------------------

  /// How many steps of a board are done. Resets on a new day when
  /// [resetDaily] is set.
  Stream<int> watchProgress(String boardId, {required bool resetDaily}) {
    final query = db.select(db.boardProgress)
      ..where((p) => p.boardId.equals(boardId));
    return query.watchSingleOrNull().map((row) {
      if (row == null) return 0;
      if (resetDaily && !_isSameDay(row.updatedAt, _clock())) return 0;
      return row.doneCount;
    });
  }

  Future<void> setProgress(String boardId, int doneCount) async {
    await db
        .into(db.boardProgress)
        .insertOnConflictUpdate(
          BoardProgressCompanion.insert(
            boardId: boardId,
            doneCount: doneCount < 0 ? 0 : doneCount,
            updatedAt: _clock(),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  Stream<AppSettings> watchSettings() {
    return db.select(db.settings).watch().map(_settingsFromRows);
  }

  Future<AppSettings> getSettings() async =>
      _settingsFromRows(await db.select(db.settings).get());

  Future<void> saveSettings(AppSettings settings) async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.settings, [
        for (final e in settings.toMap().entries)
          SettingsCompanion.insert(key: e.key, value: e.value),
      ]);
    });
  }

  Future<void> updateSettings(AppSettings Function(AppSettings) change) async {
    await saveSettings(change(await getSettings()));
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  AppSettings _settingsFromRows(List<SettingRow> rows) =>
      AppSettings.fromMap({for (final r in rows) r.key: r.value});

  /// Emits [load] now and again whenever any of [tables] changes.
  Stream<T> _onTables<T>(
    Set<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<T> Function() load,
  ) {
    return db
        .customSelect('SELECT 1', readsFrom: tables)
        .watch()
        .asyncMap((_) => load());
  }

  Board _toBoard(BoardRow row, List<StepRow> steps) => Board(
    id: row.id,
    title: row.title,
    kind: row.kind,
    updatedAt: row.updatedAt,
    steps: [for (final s in steps) _toStep(s)],
  );

  BoardStep _toStep(StepRow row) => BoardStep(
    id: row.id,
    label: row.label,
    picture: PictureRef.tryParse(row.picture),
    duration: row.durationSeconds == null || row.durationSeconds! <= 0
        ? null
        : Duration(seconds: row.durationSeconds!),
  );

  BoardStepsCompanion _stepCompanion(
    String boardId,
    int position,
    StepDraft d,
  ) => BoardStepsCompanion.insert(
    id: newId(),
    boardId: boardId,
    position: position,
    label: _cleanLabel(d.label),
    picture: Value(d.picture?.encoded),
    durationSeconds: Value(d.duration?.inSeconds),
  );

  Future<List<StepRow>> _stepRows(String boardId) =>
      (db.select(db.boardSteps)
            ..where((s) => s.boardId.equals(boardId))
            ..orderBy([(s) => OrderingTerm.asc(s.position)]))
          .get();

  Future<void> _renumber(String boardId) async {
    final steps = await _stepRows(boardId);
    await _writePositions(steps.map((s) => s.id).toList());
  }

  Future<void> _writePositions(List<String> ids) async {
    for (final (i, id) in ids.indexed) {
      await (db.update(db.boardSteps)..where((s) => s.id.equals(id))).write(
        BoardStepsCompanion(position: Value(i)),
      );
    }
  }

  Future<void> _touch(String boardId) async {
    await (db.update(db.boards)..where((b) => b.id.equals(boardId))).write(
      BoardsCompanion(updatedAt: Value(_clock())),
    );
  }

  Future<int> _minSortOrder() async {
    final min = db.boards.sortOrder.min();
    final row = await (db.selectOnly(db.boards)..addColumns([min])).getSingle();
    return row.read(min) ?? 0;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  static String _cleanTitle(String title) {
    final t = title.trim();
    if (t.isEmpty) return 'My board';
    return t.length > 80 ? t.substring(0, 80) : t;
  }

  static String _cleanLabel(String label) {
    final t = label.trim();
    return t.length > 80 ? t.substring(0, 80) : t;
  }

  static String _copyTitle(String title) {
    final copy = '$title (copy)';
    return copy.length > 80 ? copy.substring(0, 80) : copy;
  }
}
