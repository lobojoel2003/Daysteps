import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../theme.dart';

/// Keeps time for a [VisualTimer]. Uses wall-clock time, so it stays correct
/// even if frames are dropped or the app is briefly in the background.
class VisualTimerController extends ChangeNotifier {
  VisualTimerController({
    required Duration duration,
    DateTime Function()? clock,
  }) : _duration = duration <= Duration.zero
           ? const Duration(seconds: 1)
           : duration,
       _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  Duration _duration;
  Duration _elapsedBefore = Duration.zero;
  DateTime? _startedAt;
  bool _finishedNotified = false;

  Duration get duration => _duration;
  bool get isRunning => _startedAt != null && !isFinished;
  bool get hasStarted => _startedAt != null || _elapsedBefore > Duration.zero;

  Duration get elapsed {
    final started = _startedAt;
    final running = started == null
        ? Duration.zero
        : _clock().difference(started);
    final total = _elapsedBefore + running;
    return total > _duration ? _duration : total;
  }

  Duration get remaining => _duration - elapsed;

  /// 1.0 when full, 0.0 when time is up.
  double get fraction =>
      (remaining.inMicroseconds / _duration.inMicroseconds).clamp(0.0, 1.0);

  bool get isFinished => elapsed >= _duration;

  void start() {
    if (_startedAt != null || isFinished) return;
    _startedAt = _clock();
    notifyListeners();
  }

  void pause() {
    final started = _startedAt;
    if (started == null) return;
    _elapsedBefore += _clock().difference(started);
    _startedAt = null;
    notifyListeners();
  }

  void toggle() => isRunning ? pause() : start();

  void reset({Duration? duration}) {
    if (duration != null && duration > Duration.zero) _duration = duration;
    _elapsedBefore = Duration.zero;
    _startedAt = null;
    _finishedNotified = false;
    notifyListeners();
  }

  /// Returns true exactly once, the first time it is called after time runs
  /// out.
  bool takeFinished() {
    if (!isFinished || _finishedNotified) return false;
    _finishedNotified = true;
    _startedAt = null;
    _elapsedBefore = _duration;
    return true;
  }
}

/// A big, calm visual timer: a coloured disc that disappears as time passes.
/// Optionally shows a picture in the middle.
class VisualTimer extends StatefulWidget {
  const VisualTimer({
    super.key,
    required this.controller,
    required this.color,
    this.style = TimerStyle.pie,
    this.center,
    this.showDigits = false,
    this.onFinished,
    this.calm = false,
  });

  final VisualTimerController controller;
  final Color color;
  final TimerStyle style;

  /// Shown in a white circle in the middle (usually the step's picture).
  final Widget? center;
  final bool showDigits;
  final VoidCallback? onFinished;
  final bool calm;

  @override
  State<VisualTimer> createState() => _VisualTimerState();
}

class _VisualTimerState extends State<VisualTimer>
    with TickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late final AnimationController _finish = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  Duration _lastPaint = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _onControllerChanged();
  }

  @override
  void didUpdateWidget(VisualTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _onControllerChanged();
    }
  }

  void _onControllerChanged() {
    final c = widget.controller;
    if (c.isRunning && !_ticker.isActive) {
      _lastPaint = Duration.zero;
      _ticker.start();
    } else if (!c.isRunning && _ticker.isActive) {
      _ticker.stop();
    }
    if (!c.isFinished && _finish.value != 0) _finish.value = 0;
    if (mounted) setState(() {});
  }

  void _onTick(Duration elapsed) {
    final c = widget.controller;
    // Repaint ~30 times a second for short timers, ~6 for long ones.
    final interval = c.duration.inSeconds <= 120
        ? const Duration(milliseconds: 33)
        : const Duration(milliseconds: 160);
    if (elapsed - _lastPaint >= interval || c.isFinished) {
      _lastPaint = elapsed;
      setState(() {});
    }
    if (c.takeFinished()) {
      _ticker.stop();
      if (widget.calm) {
        _finish.value = 1;
      } else {
        _finish.forward(from: 0);
      }
      widget.onFinished?.call();
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _ticker.dispose();
    _finish.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final remaining = c.remaining;
    return Semantics(
      label: 'Timer',
      value: _spoken(remaining),
      liveRegion: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final digitsHeight = widget.showDigits ? 56.0 : 0.0;
          final size = math
              .min(constraints.maxWidth, constraints.maxHeight - digitsHeight)
              .clamp(48.0, 2000.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: size,
                child: AnimatedBuilder(
                  animation: _finish,
                  builder: (context, child) {
                    final pulse = widget.calm
                        ? 1.0
                        : 1 +
                              0.06 *
                                  math.sin(_finish.value * math.pi * 3) *
                                  (1 - _finish.value);
                    return Transform.scale(scale: pulse, child: child);
                  },
                  child: CustomPaint(
                    painter: TimerDiscPainter(
                      fraction: c.fraction,
                      color: widget.color,
                      style: widget.style,
                      centerFraction: widget.center == null ? 0 : 0.5,
                      finished: c.isFinished,
                    ),
                    child: widget.center == null
                        ? null
                        : Center(
                            child: FractionallySizedBox(
                              widthFactor: 0.5,
                              heightFactor: 0.5,
                              child: ClipOval(
                                child: ColoredBox(
                                  color: Colors.white,
                                  child: Padding(
                                    padding: EdgeInsets.all(size * 0.05),
                                    child: widget.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              if (widget.showDigits)
                SizedBox(
                  height: digitsHeight,
                  child: Center(
                    child: Text(
                      _digits(remaining),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: KidColors.text,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _digits(Duration d) {
    final totalSeconds = (d.inMilliseconds / 1000).ceil();
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String _spoken(Duration d) {
    final totalSeconds = (d.inMilliseconds / 1000).ceil();
    if (totalSeconds <= 0) return 'Time is up';
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m == 0) return '$s seconds left';
    return s == 0 ? '$m minutes left' : '$m minutes $s seconds left';
  }
}

/// Paints the timer disc.
class TimerDiscPainter extends CustomPainter {
  TimerDiscPainter({
    required this.fraction,
    required this.color,
    required this.style,
    this.centerFraction = 0,
    this.finished = false,
  });

  /// Time left, 1.0 (full) to 0.0.
  final double fraction;
  final Color color;
  final TimerStyle style;

  /// Diameter of the picture hole in the middle, as a fraction of the disc.
  final double centerFraction;
  final bool finished;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final face = Paint()..color = KidColors.track;
    final rim = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.04;

    canvas.drawCircle(center, radius * 0.98, face);

    final fill = Paint()
      ..color = finished ? KidColors.done : color
      ..isAntiAlias = true;
    final discRadius = radius * 0.92;
    if (finished) {
      canvas.drawCircle(center, discRadius, fill);
    } else {
      switch (style) {
        case TimerStyle.pie:
          if (fraction >= 0.9999) {
            canvas.drawCircle(center, discRadius, fill);
          } else if (fraction > 0) {
            // Counter-clockwise from twelve o'clock, like a clock hand sweeping
            // the colour away.
            canvas.drawArc(
              Rect.fromCircle(center: center, radius: discRadius),
              -math.pi / 2,
              -fraction * 2 * math.pi,
              true,
              fill,
            );
          }
        case TimerStyle.shrink:
          final inner = discRadius * centerFraction;
          final r = inner + (discRadius - inner) * math.sqrt(fraction);
          if (fraction > 0) canvas.drawCircle(center, r, fill);
      }
    }

    // Twelve gentle tick marks so the face reads as a clock.
    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = radius * 0.025
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 - math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + dir * radius * 0.93,
        center + dir * radius * (i % 3 == 0 ? 0.82 : 0.87),
        tick,
      );
    }
    canvas.drawCircle(center, radius * 0.98, rim);

    if (centerFraction > 0) {
      canvas.drawCircle(
        center,
        radius * centerFraction + radius * 0.025,
        Paint()..color = Colors.white,
      );
    } else if (finished) {
      _drawCheck(canvas, center, radius * 0.45);
    }
  }

  void _drawCheck(Canvas canvas, Offset c, double r) {
    final path = Path()
      ..moveTo(c.dx - r * 0.5, c.dy + r * 0.02)
      ..lineTo(c.dx - r * 0.12, c.dy + r * 0.4)
      ..lineTo(c.dx + r * 0.55, c.dy - r * 0.38);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(TimerDiscPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.style != style ||
      old.centerFraction != centerFraction ||
      old.finished != finished;
}

/// Formats a duration for adults, e.g. "5 min" or "1 min 30 s".
String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  if (m == 0) return '$s s';
  if (s == 0) return '$m min';
  return '$m min $s s';
}
