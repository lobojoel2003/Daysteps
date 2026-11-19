import 'dart:io';

import 'package:daysteps/src/data/repository.dart';
import 'package:daysteps/src/state/providers.dart';
import 'package:daysteps/src/symbols/symbol_catalog.dart';
import 'package:daysteps/src/ui/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';

final _catalog = SymbolCatalog.parse(
  File(SymbolCatalog.assetPath).readAsStringSync(),
);

/// Pumps [home] inside the app's providers and theme, on a tablet-sized
/// screen, backed by an in-memory database.
Future<DaystepsRepository> pumpDaysteps(
  WidgetTester tester,
  Widget Function(DaystepsRepository repo) home, {
  Future<void> Function(DaystepsRepository repo)? setup,
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = memoryRepository();
  addTearDown(repo.db.close);
  if (setup != null) await setup(repo);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        symbolCatalogProvider.overrideWithValue(_catalog),
      ],
      child: MaterialApp(theme: buildTheme(Brightness.light), home: home(repo)),
    ),
  );
  await settle(tester);
  return repo;
}

/// Lets database streams deliver and animations finish.
Future<void> settle(
  WidgetTester tester, [
  Duration step = const Duration(milliseconds: 100),
]) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(step);
  }
}
