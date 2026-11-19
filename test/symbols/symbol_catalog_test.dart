import 'dart:io';

import 'package:daysteps/src/data/seed.dart';
import 'package:daysteps/src/symbols/symbol_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late SymbolCatalog catalog;

  setUpAll(() {
    catalog = SymbolCatalog.parse(
      File(SymbolCatalog.assetPath).readAsStringSync(),
    );
  });

  test('every bundled symbol exists, is unique and is credited', () {
    expect(catalog.symbols.length, greaterThan(100));
    final ids = <String>{};
    final categories = {for (final c in catalog.categories) c.id};
    for (final s in catalog.symbols) {
      expect(ids.add(s.id), isTrue, reason: 'duplicate ${s.id}');
      expect(File(s.asset).existsSync(), isTrue, reason: s.asset);
      expect(categories, contains(s.category), reason: s.id);
      expect(catalog.sets, contains(s.set), reason: s.id);
      expect(s.label.trim(), isNotEmpty);
    }
    for (final set in catalog.sets.values) {
      expect(
        set.license,
        startsWith('CC BY-SA'),
        reason: 'only share-alike sets may be bundled',
      );
      expect(set.author, isNotEmpty);
    }
  });

  test('bundled SVGs avoid features the renderer cannot draw', () {
    for (final s in catalog.symbols) {
      final svg = File(s.asset).readAsStringSync();
      expect(svg, contains('viewBox'), reason: s.asset);
      for (final banned in [
        '<style',
        '<text',
        '<image',
        '<script',
        'xlink:href="http',
      ]) {
        expect(
          svg.contains(banned),
          isFalse,
          reason: '${s.asset} contains $banned',
        );
      }
    }
  });

  test('category covers point at real symbols', () {
    for (final c in catalog.categories) {
      expect(catalog.contains(c.cover ?? ''), isTrue, reason: c.id);
    }
  });

  test('search ranks label matches first and filters by category', () {
    final teeth = catalog.search('teeth');
    expect(teeth, isNotEmpty);
    expect(teeth.first.label.toLowerCase(), contains('teeth'));

    final all = catalog.search('');
    expect(all.length, catalog.symbols.length);

    final food = catalog.search('', category: 'food');
    expect(food, isNotEmpty);
    expect(food.every((s) => s.category == 'food'), isTrue);

    expect(catalog.search('zzzz-not-a-word'), isEmpty);
  });

  test('every example board uses a bundled symbol', () async {
    final missing = <String>[];
    final repo = memoryRepository();
    addTearDown(repo.db.close);
    await seedExampleBoards(
      repo,
      symbolExists: (id) {
        if (!catalog.contains(id)) missing.add(id);
        return catalog.contains(id);
      },
    );
    expect(missing, isEmpty);
  });
}
