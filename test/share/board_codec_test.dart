import 'dart:convert';
import 'dart:typed_data';

import 'package:daysteps/src/data/models.dart';
import 'package:daysteps/src/share/board_codec.dart';
import 'package:flutter_test/flutter_test.dart';

const _morning = SharedBoard(
  title: 'Morning',
  kind: BoardKind.schedule,
  steps: [
    SharedStep(label: 'Wake up', picture: 'sym:mulberry/wake_up'),
    SharedStep(label: 'Toilet', picture: 'sym:mulberry/toilet'),
    SharedStep(label: 'Wash hands', picture: 'sym:mulberry/wash_hands'),
    SharedStep(label: 'Get dressed', picture: 'sym:mulberry/get_dressed'),
    SharedStep(label: 'Breakfast', picture: 'sym:mulberry/breakfast'),
    SharedStep(
      label: 'Brush teeth',
      picture: 'sym:mulberry/brush_teeth',
      duration: Duration(minutes: 2),
    ),
    SharedStep(label: 'Shoes', picture: 'sym:mulberry/shoes'),
    SharedStep(label: 'Coat', picture: 'sym:mulberry/coat'),
    SharedStep(label: 'Grandma drives me', picture: 'img:photo-1'),
  ],
);

void main() {
  group('files', () {
    test('round-trip boards and photos', () {
      final photo = Uint8List.fromList(List.generate(64, (i) => i));
      final package = SharedPackage(
        boards: const [_morning],
        pictures: {
          'photo-1': SharedPicture(
            label: 'Grandma',
            mimeType: 'image/jpeg',
            bytes: photo,
            source: PictureSource.photo,
          ),
        },
      );
      final decoded = BoardCodec.decodeFile(
        BoardCodec.encodeFile(package, appVersion: '1.0.0'),
      );

      final board = decoded.boards.single;
      expect(board.title, 'Morning');
      expect(board.kind, BoardKind.schedule);
      expect(
        [for (final s in board.steps) s.label],
        [for (final s in _morning.steps) s.label],
      );
      expect(board.steps[5].duration, const Duration(minutes: 2));
      expect(board.steps.last.picture, 'img:photo-1');
      expect(decoded.pictures['photo-1']!.bytes, photo);
      expect(decoded.missingPictureCount, 0);
    });

    test('reject things that are not Daysteps files', () {
      for (final text in ['hello', '{}', '{"format":"other"}', '[1,2,3]']) {
        expect(
          () => BoardCodec.decodeFile(Uint8List.fromList(utf8.encode(text))),
          throwsA(isA<BoardFormatException>()),
          reason: text,
        );
      }
    });

    test('reject files from a newer format version', () {
      final json = jsonEncode({
        'format': BoardCodec.formatId,
        'version': 99,
        'boards': [],
      });
      expect(
        () => BoardCodec.decodeFile(Uint8List.fromList(utf8.encode(json))),
        throwsA(isA<BoardFormatException>()),
      );
    });

    test('ignore damaged pictures and unknown picture references', () {
      final json = jsonEncode({
        'format': BoardCodec.formatId,
        'version': 1,
        'boards': [
          {
            'title': 'Odd',
            'kind': 'mystery',
            'steps': [
              {'label': 'A', 'picture': 'ftp://nope'},
              {'label': 'B', 'picture': 'img:p', 'durationSeconds': -5},
              'not a step',
            ],
          },
        ],
        'pictures': {
          'p': {'label': 'x', 'mime': 'text/html', 'data': 'AAAA'},
        },
      });
      final decoded = BoardCodec.decodeFile(
        Uint8List.fromList(utf8.encode(json)),
      );
      final board = decoded.boards.single;
      expect(board.kind, BoardKind.schedule);
      expect(board.steps.length, 2);
      expect(board.steps[0].picture, isNull);
      expect(board.steps[1].duration, isNull);
      expect(decoded.pictures, isEmpty);
      expect(decoded.missingPictureCount, 1);
    });

    test('make friendly file names', () {
      expect(
        BoardCodec.fileNameFor('Morning routine!'),
        'morning-routine.daysteps',
      );
      expect(BoardCodec.fileNameFor('☀️'), 'board.daysteps');
    });
  });

  group('QR codes and links', () {
    test('round-trip a board without its photos', () {
      final code = BoardCodec.encodeQr(_morning);
      expect(code, startsWith(BoardCodec.qrPrefix));

      final board = BoardCodec.decodeQr(code);
      expect(board.title, 'Morning');
      expect(board.steps.length, _morning.steps.length);
      expect(board.steps.first.picture, 'sym:mulberry/wake_up');
      expect(board.steps[5].duration, const Duration(minutes: 2));
      expect(
        board.steps.last.picture,
        isNull,
        reason: 'photos never travel in QR codes',
      );
    });

    test('a typical schedule fits comfortably in a QR code', () {
      expect(
        BoardCodec.encodeLink(_morning).length,
        lessThan(BoardCodec.maxQrLength),
      );
    });

    test('links to the web app decode too', () {
      final link = BoardCodec.encodeLink(_morning);
      expect(link, startsWith(BoardCodec.webAppUrl));
      expect(BoardCodec.looksLikeQr(link), isTrue);
      expect(BoardCodec.decodeQr(link).title, 'Morning');
    });

    test('first–then boards keep their kind', () {
      const board = SharedBoard(
        title: 'Homework, then tablet',
        kind: BoardKind.firstThen,
        steps: [
          SharedStep(
            label: 'Homework',
            picture: 'sym:mulberry/homework',
            duration: Duration(minutes: 15),
          ),
          SharedStep(label: 'Tablet', picture: 'sym:openmoji/tablet'),
        ],
      );
      final decoded = BoardCodec.decodeQr(BoardCodec.encodeQr(board));
      expect(decoded.kind, BoardKind.firstThen);
      expect(decoded.steps.first.duration, const Duration(minutes: 15));
    });

    test('reject codes that are not Daysteps codes', () {
      for (final text in [
        '',
        'https://example.com',
        'DS1.',
        'DS1.!!!!',
        'DS1.AAAA',
      ]) {
        expect(
          () => BoardCodec.decodeQr(text),
          throwsA(isA<BoardFormatException>()),
          reason: text,
        );
      }
      expect(BoardCodec.looksLikeQr('https://example.com'), isFalse);
    });
  });
}
