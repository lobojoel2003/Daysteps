import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../data/models.dart';

/// Thrown when shared data cannot be read.
class BoardFormatException implements Exception {
  const BoardFormatException(this.message);
  final String message;

  @override
  String toString() => 'BoardFormatException: $message';
}

/// A board as it travels between devices.
@immutable
class SharedBoard {
  const SharedBoard({
    required this.title,
    required this.kind,
    required this.steps,
  });

  final String title;
  final BoardKind kind;
  final List<SharedStep> steps;
}

@immutable
class SharedStep {
  const SharedStep({required this.label, this.picture, this.duration});

  final String label;

  /// `sym:<id>` or `img:<key into SharedPackage.pictures>`.
  final String? picture;
  final Duration? duration;
}

/// A stored picture embedded in a share file.
@immutable
class SharedPicture {
  const SharedPicture({
    required this.label,
    required this.mimeType,
    required this.bytes,
    required this.source,
    this.attribution,
    this.remoteId,
  });

  final String label;
  final String mimeType;
  final Uint8List bytes;
  final PictureSource source;
  final String? attribution;
  final String? remoteId;
}

/// One or more boards plus the photos they use.
@immutable
class SharedPackage {
  const SharedPackage({required this.boards, this.pictures = const {}});

  final List<SharedBoard> boards;
  final Map<String, SharedPicture> pictures;

  /// Pictures referenced by [boards] that are not included (QR codes never
  /// carry photos).
  int get missingPictureCount {
    var missing = 0;
    for (final b in boards) {
      for (final s in b.steps) {
        final ref = PictureRef.tryParse(s.picture);
        if (ref is StoredPicture && !pictures.containsKey(ref.pictureId)) {
          missing++;
        }
      }
    }
    return missing;
  }
}

/// Encodes and decodes Daysteps share files (`.daysteps`, JSON) and the compact
/// form used in QR codes and links.
abstract final class BoardCodec {
  static const fileExtension = 'daysteps';
  static const mimeType = 'application/json';
  static const formatId = 'daysteps.boards';
  static const formatVersion = 1;

  /// Prefix of the compact QR/link payload.
  static const qrPrefix = 'DS1.';

  /// Public web app; QR codes are links to it so any phone camera can open
  /// them, and the Android app recognises the same link.
  static const webAppUrl = 'https://lobojoel2003.github.io/Daysteps/';

  /// Byte-mode QR codes hold at most 2,953 bytes (error correction level L).
  /// We stay well below that so codes remain easy to scan.
  static const maxQrLength = 1800;

  static const _maxSteps = 200;
  static const _maxBoards = 500;
  static const _maxFileBytes = 64 * 1024 * 1024;

  // ---------------------------------------------------------------------------
  // Files
  // ---------------------------------------------------------------------------

  static Uint8List encodeFile(SharedPackage package, {String? appVersion}) {
    final json = <String, Object?>{
      'format': formatId,
      'version': formatVersion,
      'app': ?appVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'boards': [for (final b in package.boards) _boardToJson(b)],
      'pictures': {
        for (final e in package.pictures.entries)
          e.key: {
            'label': e.value.label,
            'mime': e.value.mimeType,
            'source': e.value.source.name,
            'attribution': ?e.value.attribution,
            'remoteId': ?e.value.remoteId,
            'data': base64Encode(e.value.bytes),
          },
      },
    };
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent(' ').convert(json)),
    );
  }

  static SharedPackage decodeFile(Uint8List bytes) {
    if (bytes.length > _maxFileBytes) {
      throw const BoardFormatException('This file is too large.');
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const BoardFormatException('This is not a Daysteps file.');
    }
    if (json is! Map<String, dynamic> || json['format'] != formatId) {
      throw const BoardFormatException('This is not a Daysteps file.');
    }
    final version = json['version'];
    if (version is! int || version > formatVersion) {
      throw const BoardFormatException(
        'This file was made by a newer version of Daysteps. Please update the app.',
      );
    }
    final boardsJson = json['boards'];
    if (boardsJson is! List || boardsJson.isEmpty) {
      throw const BoardFormatException('This file has no boards in it.');
    }
    if (boardsJson.length > _maxBoards) {
      throw const BoardFormatException('This file has too many boards.');
    }
    final boards = [for (final b in boardsJson) _boardFromJson(b)];

    final pictures = <String, SharedPicture>{};
    final picturesJson = json['pictures'];
    if (picturesJson is Map<String, dynamic>) {
      for (final e in picturesJson.entries) {
        final p = e.value;
        if (p is! Map<String, dynamic>) continue;
        final data = p['data'];
        final mime = p['mime'];
        if (data is! String || mime is! String || !mime.startsWith('image/')) {
          continue;
        }
        final Uint8List pictureBytes;
        try {
          pictureBytes = base64Decode(data);
        } on FormatException {
          continue;
        }
        pictures[e.key] = SharedPicture(
          label: _string(p['label'], fallback: ''),
          mimeType: mime,
          bytes: pictureBytes,
          source:
              PictureSource.values.asNameMap()[p['source']] ??
              PictureSource.photo,
          attribution: p['attribution'] as String?,
          remoteId: p['remoteId'] as String?,
        );
      }
    }
    return SharedPackage(boards: boards, pictures: pictures);
  }

  /// A friendly file name for a board, e.g. `morning-routine.daysteps`.
  static String fileNameFor(String title) {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${slug.isEmpty ? 'board' : slug}.$fileExtension';
  }

  // ---------------------------------------------------------------------------
  // QR codes and links
  // ---------------------------------------------------------------------------

  /// Compact text for a QR code: `DS1.<base64url(deflate(json))>`.
  /// Photos are left out (only words and bundled pictograms fit).
  static String encodeQr(SharedBoard board) {
    final compact = <String, Object?>{
      't': board.title,
      'k': board.kind.index,
      's': [
        for (final s in board.steps)
          [
            s.label,
            switch (PictureRef.tryParse(s.picture)) {
              SymbolPicture(:final symbolId) => symbolId,
              _ => '',
            },
            if (s.duration != null) s.duration!.inSeconds,
          ],
      ],
    };
    final packed = const ZLibEncoder().encodeBytes(
      utf8.encode(jsonEncode(compact)),
      level: 9,
    );
    return '$qrPrefix${base64Url.encode(packed).replaceAll('=', '')}';
  }

  /// A link that opens the board in the web app (and in the Android app's
  /// scanner).
  static String encodeLink(SharedBoard board) =>
      '$webAppUrl#import=${encodeQr(board)}';

  /// Whether [text] looks like a Daysteps QR payload or link.
  static bool looksLikeQr(String text) => _extractPayload(text) != null;

  static SharedBoard decodeQr(String text) {
    final payload = _extractPayload(text);
    if (payload == null) {
      throw const BoardFormatException('This is not a Daysteps code.');
    }
    final Object? json;
    try {
      final padded = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      const limit = 256 * 1024;
      final inflated = const ZLibDecoder().decodeBytes(
        base64Url.decode(padded),
        verify: true,
        throwOnError: true,
        maxOutputSize: limit + 1,
      );
      if (inflated.length > limit) {
        throw const BoardFormatException('This code is too large.');
      }
      json = jsonDecode(utf8.decode(inflated));
    } on BoardFormatException {
      rethrow;
    } catch (_) {
      throw const BoardFormatException('This code could not be read.');
    }
    if (json is! Map<String, dynamic>) {
      throw const BoardFormatException('This code could not be read.');
    }
    final kindIndex = json['k'];
    final kind =
        kindIndex is int &&
            kindIndex >= 0 &&
            kindIndex < BoardKind.values.length
        ? BoardKind.values[kindIndex]
        : BoardKind.schedule;
    final steps = <SharedStep>[];
    final stepsJson = json['s'];
    if (stepsJson is List) {
      for (final s in stepsJson.take(_maxSteps)) {
        if (s is! List || s.isEmpty) continue;
        final symbol = s.length > 1 ? s[1] : null;
        final seconds = s.length > 2 ? s[2] : null;
        steps.add(
          SharedStep(
            label: _string(s[0], fallback: ''),
            picture: symbol is String && symbol.isNotEmpty
                ? SymbolPicture(symbol).encoded
                : null,
            duration: _duration(seconds),
          ),
        );
      }
    }
    return SharedBoard(
      title: _string(json['t'], fallback: 'Shared board'),
      kind: kind,
      steps: steps,
    );
  }

  static String? _extractPayload(String text) {
    final trimmed = text.trim();
    final at = trimmed.indexOf(qrPrefix);
    if (at < 0) return null;
    var payload = trimmed.substring(at + qrPrefix.length);
    final end = payload.indexOf(RegExp(r'[^A-Za-z0-9_\-=]'));
    if (end >= 0) payload = payload.substring(0, end);
    if (payload.isEmpty) return null;
    return payload;
  }

  // ---------------------------------------------------------------------------
  // JSON helpers
  // ---------------------------------------------------------------------------

  static Map<String, Object?> _boardToJson(SharedBoard b) => {
    'title': b.title,
    'kind': b.kind.name,
    'steps': [
      for (final s in b.steps)
        {
          'label': s.label,
          'picture': ?s.picture,
          if (s.duration != null) 'durationSeconds': s.duration!.inSeconds,
        },
    ],
  };

  static SharedBoard _boardFromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const BoardFormatException('A board in this file is damaged.');
    }
    final kind =
        BoardKind.values.asNameMap()[json['kind']] ?? BoardKind.schedule;
    final stepsJson = json['steps'];
    final steps = <SharedStep>[];
    if (stepsJson is List) {
      for (final s in stepsJson.take(_maxSteps)) {
        if (s is! Map<String, dynamic>) continue;
        final picture = s['picture'];
        steps.add(
          SharedStep(
            label: _string(s['label'], fallback: ''),
            picture: picture is String && PictureRef.tryParse(picture) != null
                ? picture
                : null,
            duration: _duration(s['durationSeconds']),
          ),
        );
      }
    }
    return SharedBoard(
      title: _string(json['title'], fallback: 'Shared board'),
      kind: kind,
      steps: steps,
    );
  }

  static String _string(Object? value, {required String fallback}) {
    if (value is! String) return fallback;
    final t = value.trim();
    if (t.isEmpty) return fallback;
    return t.length > 80 ? t.substring(0, 80) : t;
  }

  static Duration? _duration(Object? seconds) {
    if (seconds is! int || seconds <= 0) return null;
    return Duration(seconds: seconds.clamp(1, 24 * 60 * 60));
  }
}
