import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart';

/// A pictogram set bundled with the app, with its license details.
@immutable
class SymbolSet {
  const SymbolSet({
    required this.id,
    required this.name,
    required this.author,
    required this.license,
    required this.licenseUrl,
    required this.url,
  });

  final String id;
  final String name;
  final String author;
  final String license;
  final String licenseUrl;
  final String url;

  factory SymbolSet.fromJson(String id, Map<String, dynamic> json) => SymbolSet(
    id: id,
    name: json['name'] as String? ?? id,
    author: json['author'] as String? ?? '',
    license: json['license'] as String? ?? '',
    licenseUrl: json['licenseUrl'] as String? ?? '',
    url: json['url'] as String? ?? '',
  );
}

@immutable
class SymbolCategory {
  const SymbolCategory({required this.id, required this.label, this.cover});

  final String id;
  final String label;

  /// Id of a symbol used as the category's thumbnail.
  final String? cover;

  factory SymbolCategory.fromJson(Map<String, dynamic> json) => SymbolCategory(
    id: json['id'] as String,
    label: json['label'] as String? ?? json['id'] as String,
    cover: json['cover'] as String?,
  );
}

/// One bundled pictogram.
@immutable
class SymbolInfo {
  SymbolInfo({
    required this.id,
    required this.set,
    required this.asset,
    required this.label,
    required this.category,
    this.keywords = const [],
  }) : _haystack = [
         label,
         ...keywords,
         id.split('/').last.replaceAll('_', ' '),
       ].join(' ').toLowerCase();

  final String id;
  final String set;
  final String asset;
  final String label;
  final String category;
  final List<String> keywords;

  factory SymbolInfo.fromJson(Map<String, dynamic> json) => SymbolInfo(
    id: json['id'] as String,
    set: json['set'] as String,
    asset: json['asset'] as String,
    label: json['label'] as String,
    category: json['category'] as String? ?? '',
    keywords: [
      for (final k in (json['keywords'] as List? ?? const [])) k.toString(),
    ],
  );

  /// Lower-case text used for searching.
  final String _haystack;
}

/// The catalogue of bundled pictograms (`assets/symbols/catalog.json`).
class SymbolCatalog {
  SymbolCatalog({
    required this.sets,
    required this.categories,
    required List<SymbolInfo> symbols,
  }) : symbols = List.unmodifiable(symbols),
       _byId = {for (final s in symbols) s.id: s};

  static const assetPath = 'assets/symbols/catalog.json';

  final Map<String, SymbolSet> sets;
  final List<SymbolCategory> categories;
  final List<SymbolInfo> symbols;
  final Map<String, SymbolInfo> _byId;

  static final empty = SymbolCatalog(
    sets: const {},
    categories: const [],
    symbols: const [],
  );

  static Future<SymbolCatalog> load([AssetBundle? bundle]) async {
    final source = await (bundle ?? rootBundle).loadString(assetPath);
    return parse(source);
  }

  static SymbolCatalog parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final sets = <String, SymbolSet>{
      for (final e
          in (json['sets'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: SymbolSet.fromJson(e.key, e.value as Map<String, dynamic>),
    };
    return SymbolCatalog(
      sets: sets,
      categories: [
        for (final c in (json['categories'] as List? ?? const []))
          SymbolCategory.fromJson(c as Map<String, dynamic>),
      ],
      symbols: [
        for (final s in (json['symbols'] as List? ?? const []))
          SymbolInfo.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  SymbolInfo? operator [](String id) => _byId[id];

  bool contains(String id) => _byId.containsKey(id);

  /// Finds symbols whose label or keywords match every word of [query],
  /// optionally limited to one [category]. Label matches rank first.
  List<SymbolInfo> search(String query, {String? category}) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final pool = category == null
        ? symbols
        : symbols.where((s) => s.category == category);
    if (words.isEmpty) return pool.toList();

    final matches = pool
        .where((s) => words.every((w) => s._haystack.contains(w)))
        .toList();
    int rank(SymbolInfo s) {
      final label = s.label.toLowerCase();
      if (label == query.toLowerCase().trim()) return 0;
      if (label.startsWith(words.first)) return 1;
      if (label.contains(words.first)) return 2;
      return 3;
    }

    mergeSort(matches, compare: (a, b) => rank(a).compareTo(rank(b)));
    return matches;
  }

  /// The best bundled symbol for a free-text label, if any.
  SymbolInfo? bestMatch(String label) {
    final results = search(label);
    return results.isEmpty ? null : results.first;
  }
}
