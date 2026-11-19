import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/done_burst.dart';
import 'child_shell.dart';
import 'kid_card.dart';
import 'step_timer.dart';

/// "First this, then that." Two big cards; the current one is highlighted.
class FirstThenPlayer extends ConsumerStatefulWidget {
  const FirstThenPlayer({
    super.key,
    required this.board,
    required this.initialDone,
  });

  final Board board;
  final int initialDone;

  @override
  ConsumerState<FirstThenPlayer> createState() => _FirstThenPlayerState();
}

class _FirstThenPlayerState extends ConsumerState<FirstThenPlayer> {
  late int _done = widget.initialDone.clamp(0, 2);
  int _burst = 0;
  bool _busy = false;
  bool _timerFinished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  void _say(String text) => unawaited(ref.read(speakerProvider).say(text));

  void _announce() {
    final first = widget.board.first;
    final then = widget.board.then;
    if (first == null || then == null) return;
    switch (_done) {
      case 0:
        _say('First ${first.label}, then ${then.label}');
      case 1:
        _say(then.label);
      default:
        _say('All done!');
    }
  }

  Future<void> _markDone() async {
    if (_busy || _done >= 2) return;
    final calm = calmMotionOf(
      context,
      setting: ref.read(currentSettingsProvider).calmMotion,
    );
    setState(() {
      _busy = true;
      _burst++;
    });
    unawaited(HapticFeedback.mediumImpact());
    await Future<void>.delayed(Duration(milliseconds: calm ? 350 : 650));
    if (!mounted) return;
    setState(() {
      _done++;
      _busy = false;
      _timerFinished = false;
    });
    unawaited(ref.read(repositoryProvider).setProgress(widget.board.id, _done));
    _announce();
  }

  Future<void> _restart() async {
    setState(() {
      _done = 0;
      _timerFinished = false;
    });
    await ref.read(repositoryProvider).setProgress(widget.board.id, 0);
    _announce();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(currentSettingsProvider);
    final calm = calmMotionOf(context, setting: settings.calmMotion);
    final first = widget.board.first!;
    final then = widget.board.then!;

    Widget card(BoardStep step, int index, String tag) {
      final isCurrent = _done == index;
      final isDone = _done > index;
      final duration = step.duration;
      return AnimatedScale(
        scale: isCurrent ? 1 : 0.88,
        duration: Duration(milliseconds: calm ? 0 : 450),
        curve: Curves.easeOutBack,
        child: KidCard(
          step: step,
          role: isCurrent ? KidCardRole.now : KidCardRole.next,
          tag: tag,
          showLabel: settings.showLabels,
          dimmed: isDone,
          onTap: () => _say(step.label),
          pictureOverride: isCurrent && duration != null
              ? StepTimer(
                  key: ValueKey('timer-${step.id}'),
                  step: step,
                  duration: duration,
                  onFinished: () => setState(() => _timerFinished = true),
                )
              : null,
          footer: isCurrent
              ? DoneButton(
                  onPressed: _busy ? null : _markDone,
                  attention: _timerFinished,
                )
              : (isDone
                    ? const SizedBox(
                        height: 96,
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: KidColors.done,
                          size: 72,
                        ),
                      )
                    : const SizedBox(height: 96)),
        ),
      );
    }

    return ChildShell(
      actions: [
        ChildMenuAction(
          icon: Icons.replay_rounded,
          label: 'Start again',
          onSelected: _restart,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > constraints.maxHeight;
                  return Flex(
                    direction: wide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: card(first, 0, 'First'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: Icon(
                            wide
                                ? Icons.arrow_forward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 56,
                            color: KidColors.muted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: card(then, 1, 'Then'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_done >= 2)
              const Center(child: _Finished())
            else
              // Centred on the card being finished (first, then).
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth > c.maxHeight;
                  final side = _done == 0 ? -0.55 : 0.55;
                  return Align(
                    alignment: wide ? Alignment(side, 0) : Alignment(0, side),
                    child: DoneBurst(trigger: _burst, calm: calm, size: 200),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 120, color: Brand.sunflower),
          Text(
            'All done!',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: KidColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
