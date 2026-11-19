import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/picture_view.dart';
import '../widgets/visual_timer.dart';

/// The picture of a timed step, inside a visual timer. Tap to start or pause.
class StepTimer extends ConsumerStatefulWidget {
  const StepTimer({
    super.key,
    required this.step,
    required this.duration,
    this.autoStart = false,
    this.onFinished,
  });

  final BoardStep step;
  final Duration duration;
  final bool autoStart;
  final VoidCallback? onFinished;

  @override
  ConsumerState<StepTimer> createState() => _StepTimerState();
}

class _StepTimerState extends ConsumerState<StepTimer> {
  late final VisualTimerController _controller = VisualTimerController(
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finished() {
    unawaited(HapticFeedback.heavyImpact());
    unawaited(SystemSound.play(SystemSoundType.alert));
    unawaited(ref.read(speakerProvider).say('Time is up'));
    widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(currentSettingsProvider);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final waiting = !_controller.hasStarted;
        return Semantics(
          button: true,
          label: waiting
              ? 'Start timer'
              : (_controller.isRunning ? 'Pause timer' : 'Timer'),
          child: GestureDetector(
            onTap: _controller.isFinished
                ? () => ref.read(speakerProvider).say(widget.step.label)
                : () {
                    _controller.toggle();
                    if (_controller.isRunning) {
                      unawaited(HapticFeedback.selectionClick());
                    }
                  },
            child: Stack(
              alignment: Alignment.center,
              children: [
                VisualTimer(
                  controller: _controller,
                  color: Color(settings.timerColor),
                  style: settings.timerStyle,
                  showDigits: settings.showTimeLeft,
                  calm: settings.calmMotion,
                  onFinished: _finished,
                  center: PictureView(
                    picture: widget.step.picture,
                    label: widget.step.label,
                  ),
                ),
                if (waiting ||
                    (!_controller.isRunning && !_controller.isFinished))
                  const _PlayBadge(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0.62, 0.62),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            size: 44,
            color: Color(0xFF21323A),
          ),
        ),
      ),
    );
  }
}
