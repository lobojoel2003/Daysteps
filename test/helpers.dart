import 'package:daysteps/src/data/database.dart';
import 'package:daysteps/src/data/repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// A repository backed by a fresh in-memory SQLite database.
DaystepsRepository memoryRepository({DateTime Function()? clock}) {
  // Tests open several independent databases on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  return DaystepsRepository(db, clock: clock);
}
