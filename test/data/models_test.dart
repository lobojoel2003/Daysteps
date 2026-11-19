import 'package:daysteps/src/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PictureRef', () {
    test('parses symbols and stored pictures', () {
      expect(
        PictureRef.tryParse('sym:mulberry/toilet'),
        const SymbolPicture('mulberry/toilet'),
      );
      expect(PictureRef.tryParse('img:1234'), const StoredPicture('1234'));
    });

    test('rejects empty and unknown values', () {
      for (final value in [
        null,
        '',
        'sym:',
        'img:',
        'http://x',
        'mulberry/toilet',
      ]) {
        expect(PictureRef.tryParse(value), isNull, reason: '$value');
      }
    });

    test('round-trips through its encoded form', () {
      const refs = [SymbolPicture('openmoji/tablet'), StoredPicture('abc')];
      for (final ref in refs) {
        expect(PictureRef.tryParse(ref.encoded), ref);
      }
    });
  });

  group('AppSettings', () {
    test('round-trips through the key/value map', () {
      const settings = AppSettings(
        speechEnabled: false,
        speechRate: 0.7,
        showLabels: false,
        calmMotion: true,
        timerColor: 0xFF3A86FF,
        timerStyle: TimerStyle.shrink,
        showTimeLeft: true,
        openInChildMode: true,
        resetDaily: false,
        activeBoardId: 'board-1',
        seeded: true,
      );
      expect(AppSettings.fromMap(settings.toMap()), settings);
    });

    test('falls back to defaults for missing or broken values', () {
      final settings = AppSettings.fromMap({
        'speechRate': 'fast',
        'timerStyle': 'spiral',
        'speechEnabled': 'maybe',
        'activeBoardId': '',
      });
      expect(settings, const AppSettings());
    });

    test('clamps the speech rate', () {
      expect(AppSettings.fromMap({'speechRate': '5'}).speechRate, 1.0);
      expect(AppSettings.fromMap({'speechRate': '0'}).speechRate, 0.1);
    });
  });

  test('first–then boards need both cards to be playable', () {
    final board = Board(
      id: 'b',
      title: 'Homework',
      kind: BoardKind.firstThen,
      updatedAt: DateTime(2026),
      steps: const [BoardStep(id: '1', label: 'Homework')],
    );
    expect(board.isPlayable, isFalse);
    expect(board.first?.label, 'Homework');
    expect(board.then, isNull);
  });
}
