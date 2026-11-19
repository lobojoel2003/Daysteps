import 'dart:ui';

import 'package:daysteps/src/data/models.dart';
import 'package:daysteps/src/ui/widgets/visual_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VisualTimerController', () {
    late DateTime now;
    late VisualTimerController timer;

    setUp(() {
      now = DateTime(2026, 1, 1, 9);
      timer = VisualTimerController(
        duration: const Duration(minutes: 2),
        clock: () => now,
      );
    });

    test('starts full and counts down with the wall clock', () {
      expect(timer.fraction, 1.0);
      expect(timer.hasStarted, isFalse);

      timer.start();
      now = now.add(const Duration(seconds: 30));
      expect(timer.fraction, closeTo(0.75, 1e-9));
      expect(timer.remaining, const Duration(seconds: 90));
    });

    test('pausing stops time', () {
      timer.start();
      now = now.add(const Duration(seconds: 60));
      timer.pause();
      now = now.add(const Duration(minutes: 10));
      expect(timer.fraction, closeTo(0.5, 1e-9));
      expect(timer.isRunning, isFalse);

      timer.start();
      now = now.add(const Duration(seconds: 30));
      expect(timer.remaining, const Duration(seconds: 30));
    });

    test('reports finishing exactly once', () {
      timer.start();
      now = now.add(const Duration(minutes: 3));
      expect(timer.isFinished, isTrue);
      expect(timer.fraction, 0);
      expect(timer.takeFinished(), isTrue);
      expect(timer.takeFinished(), isFalse);

      timer.reset();
      expect(timer.fraction, 1.0);
      expect(timer.isFinished, isFalse);
    });
  });

  test('formatDuration is short and clear', () {
    expect(formatDuration(const Duration(seconds: 45)), '45 s');
    expect(formatDuration(const Duration(minutes: 5)), '5 min');
    expect(
      formatDuration(const Duration(minutes: 1, seconds: 30)),
      '1 min 30 s',
    );
  });

  test('the disc painter repaints only when something changes', () {
    TimerDiscPainter painter(double f) => TimerDiscPainter(
      fraction: f,
      color: const Color(0xFFE4572E),
      style: TimerStyle.pie,
    );
    expect(painter(0.5).shouldRepaint(painter(0.5)), isFalse);
    expect(painter(0.5).shouldRepaint(painter(0.4)), isTrue);
  });
}
