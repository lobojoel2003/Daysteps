import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/picture_view.dart';
import '../widgets/visual_timer.dart';
import 'child_shell.dart';

/// A full-screen visual timer for the child: a coloured disc that shrinks as
/// time passes, with an optional picture of what it's for.
class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({
    super.key,
    required this.duration,
    this.picture,
    this.label = '',
  });

  final Duration duration;
  final PictureRef? picture;
  final String label;

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  late final VisualTimerController _controller = VisualTimerController(
    duration: widget.duration,
  )..start();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.label.isNotEmpty) {
        unawaited(ref.read(speakerProvider).say(widget.label));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finished() {
    unawaited(HapticFeedback.heavyImpact());
    unawaited(SystemSound.play(SystemSoundType.alert));
    unawaited(ref.read(speakerProvider).say('All done!'));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(currentSettingsProvider);
    final hasPicture = widget.picture != null;
    return ChildShell(
      actions: [
        ChildMenuAction(
          icon: Icons.replay_rounded,
          label: 'Start the timer again',
          onSelected: () => _controller
            ..reset()
            ..start(),
        ),
        ChildMenuAction(
          icon: Icons.pause_rounded,
          label: 'Pause or continue',
          onSelected: _controller.toggle,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: VisualTimer(
                  controller: _controller,
                  color: Color(settings.timerColor),
                  style: settings.timerStyle,
                  showDigits: settings.showTimeLeft,
                  calm: settings.calmMotion,
                  onFinished: _finished,
                  center: hasPicture
                      ? PictureView(
                          picture: widget.picture,
                          label: widget.label,
                        )
                      : null,
                ),
              ),
            ),
            if (widget.label.isNotEmpty && settings.showLabels)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: KidColors.text,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
