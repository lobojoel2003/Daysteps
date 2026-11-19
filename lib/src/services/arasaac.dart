import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One search result from the ARASAAC catalogue.
@immutable
class ArasaacPictogram {
  const ArasaacPictogram({required this.id, required this.label});

  final int id;
  final String label;

  /// A small preview image (only fetched while the adult is searching).
  Uri get previewUrl => ArasaacClient.imageUrl(id, size: 300);
}

/// Optional, online-only access to the ARASAAC pictograms
/// (https://arasaac.org).
///
/// ARASAAC pictograms are by Sergio Palao, owned by the Government of Aragón
/// and published under CC BY-NC-SA 4.0. Because that license forbids
/// commercial use, they are **not** bundled with Daysteps. An adult can choose
/// to download individual pictograms, which are then stored on the device with
/// their attribution and work offline from then on.
class ArasaacClient {
  ArasaacClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const apiBase = 'https://api.arasaac.org/v1';
  static const staticBase = 'https://static.arasaac.org/pictograms';
  static const license = 'CC BY-NC-SA 4.0';
  static const licenseUrl =
      'https://creativecommons.org/licenses/by-nc-sa/4.0/';
  static const attribution =
      'Pictogram author: Sergio Palao. Origin: ARASAAC (https://arasaac.org). '
      'License: CC BY-NC-SA 4.0. Owner: Government of Aragón (Spain).';

  static Uri imageUrl(int id, {int size = 500}) =>
      Uri.parse('$staticBase/$id/${id}_$size.png');

  /// Searches pictograms by keyword. [locale] is an ARASAAC language code
  /// such as `en`, `es` or `fr`.
  Future<List<ArasaacPictogram>> search(
    String query, {
    String locale = 'en',
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.parse(
      '$apiBase/pictograms/$locale/search/${Uri.encodeComponent(q)}',
    );
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) return const []; // no matches
    if (response.statusCode != 200) {
      throw ArasaacException('ARASAAC search failed (${response.statusCode}).');
    }
    return parseSearch(response.body, fallbackLabel: q);
  }

  /// Parses the JSON returned by the search endpoint.
  @visibleForTesting
  static List<ArasaacPictogram> parseSearch(
    String body, {
    String fallbackLabel = '',
  }) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw const ArasaacException('ARASAAC sent an unexpected answer.');
    }
    if (json is! List) return const [];
    final results = <ArasaacPictogram>[];
    for (final item in json) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['_id'];
      if (id is! int) continue;
      var label = fallbackLabel;
      final keywords = item['keywords'];
      if (keywords is List && keywords.isNotEmpty) {
        final first = keywords.first;
        if (first is Map<String, dynamic> && first['keyword'] is String) {
          label = first['keyword'] as String;
        }
      }
      results.add(ArasaacPictogram(id: id, label: _sentenceCase(label)));
    }
    return results;
  }

  /// Downloads a pictogram as PNG bytes.
  Future<Uint8List> download(int id, {int size = 500}) async {
    final response = await _client
        .get(imageUrl(id, size: size))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw ArasaacException(
        'Could not download pictogram $id (${response.statusCode}).',
      );
    }
    return response.bodyBytes;
  }

  void close() => _client.close();

  static String _sentenceCase(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }
}

class ArasaacException implements Exception {
  const ArasaacException(this.message);
  final String message;

  @override
  String toString() => message;
}
