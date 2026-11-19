import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The satisfying "done" moment: a big green tick pops in and a ring of
/// confetti bursts outwards, then everything fades.
///
/// Increase [trigger] to play it. With [calm] set it's a gentle fade instead
/// of a burst.
class DoneBurst extends StatefulWidget {
  const DoneBurst({
    super.key,
    required this.trigger,
    this.calm = false,
    this.size = 220,
  });

  final int trigger;
  final bool calm;
  final double size;

  @override
  State<DoneBurst> createState() => _DoneBurstState();
}

class _DoneBurstState extends State<DoneBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  List<_Particle> _particles = const [];
  final _random = math.Random();

  @override
  void didUpdateWidget(DoneBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) _play();
  }

  void _play() {
    _particles = widget.calm ? const [] : _makeParticles();
    _controller.forward(from: 0);
  }

  List<_Particle> _makeParticles() {
    const colors = [
      Brand.sunflower,
      Brand.coral,
      Brand.leaf,
      Color(0xFF3A86FF),
      Color(0xFF8E5CF7),
    ];
    return List.generate(22, (i) {
      final angle = (i / 22) * 2 * math.pi + _random.nextDouble() * 0.3;
      return _Particle(
        angle: angle,
        distance: 0.55 + _random.nextDouble() * 0.45,
        size: 0.03 + _random.nextDouble() * 0.035,
        color: colors[i % colors.length],
        star: i % 3 == 0,
        spin: (_random.nextDouble() - 0.5) * 6,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isDismissed) return const SizedBox.shrink();
          final t = _controller.value;
          return SizedBox.square(
            dimension: widget.size * 1.8,
            child: CustomPaint(
              painter: _BurstPainter(
                t: t,
                particles: _particles,
                calm: widget.calm,
                checkSize: widget.size,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.star,
    required this.spin,
  });

  final double angle;
  final double distance;
  final double size;
  final Color color;
  final bool star;
  final double spin;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.t,
    required this.particles,
    required this.calm,
    required this.checkSize,
  });

  final double t;
  final List<_Particle> particles;
  final bool calm;
  final double checkSize;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final extent = size.shortestSide / 2;

    // Confetti.
    final fly = Curves.easeOutCubic.transform(t.clamp(0, 1));
    final fade = (1 - Curves.easeIn.transform(((t - 0.45) / 0.55).clamp(0, 1)));
    for (final p in particles) {
      final d = extent * p.distance * fly;
      final pos =
          c +
          Offset(math.cos(p.angle), math.sin(p.angle)) * d +
          Offset(0, extent * 0.12 * t * t);
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      final r = extent * p.size * (1 - 0.3 * t);
      if (p.star) {
        _drawStar(canvas, pos, r * 1.4, p.spin * t, paint);
      } else {
        canvas.drawCircle(pos, r, paint);
      }
    }

    // The tick.
    final double scale;
    final double opacity;
    if (calm) {
      scale = 1;
      opacity = t < 0.2 ? t / 0.2 : (t > 0.75 ? (1 - t) / 0.25 : 1);
    } else {
      scale = t < 0.55
          ? Curves.elasticOut.transform((t / 0.55).clamp(0, 1))
          : 1 + 0.05 * (1 - (t - 0.55) / 0.45);
      opacity = t > 0.8 ? (1 - t) / 0.2 : 1;
    }
    final radius = checkSize / 2 * scale;
    if (radius <= 0) return;
    canvas.drawCircle(
      c + const Offset(0, 6),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      c,
      radius,
      Paint()..color = KidColors.done.withValues(alpha: opacity),
    );
    final r = radius * 0.55;
    final tick = Path()
      ..moveTo(c.dx - r * 0.55, c.dy + r * 0.02)
      ..lineTo(c.dx - r * 0.12, c.dy + r * 0.45)
      ..lineTo(c.dx + r * 0.62, c.dy - r * 0.42);
    canvas.drawPath(
      tick,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.26
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawStar(
    Canvas canvas,
    Offset c,
    double r,
    double rotation,
    Paint paint,
  ) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = rotation + i * math.pi / 5 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.45;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.t != t || old.particles != particles;
}
