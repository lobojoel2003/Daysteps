import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/done_burst.dart';
import '../widgets/picture_view.dart';
import 'child_shell.dart';
import 'kid_card.dart';
import 'step_timer.dart';

/// Plays a schedule for the child: the current step large and highlighted,
/// the next step beside it, and a rail of all steps at the top.
class SchedulePlayer extends ConsumerStatefulWidget {
  const SchedulePlayer({
    super.key,
    required this.board,
    required this.initialDone,
  });

  final Board board;
  final int initialDone;

  @override
  ConsumerState<SchedulePlayer> createState() => _SchedulePlayerState();
}

class _SchedulePlayerState extends ConsumerState<SchedulePlayer> {
  late int _done = widget.initialDone.clamp(0, widget.board.steps.length);
  int _burst = 0;
  bool _busy = false;
  bool _timerFinished = false;

  List<BoardStep> get _steps => widget.board.steps;
  BoardStep? get _current => _done < _steps.length ? _steps[_done] : null;
  BoardStep? get _next => _done + 1 < _steps.length ? _steps[_done + 1] : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = _current;
      if (current != null) _say(current.label);
    });
  }

  @override
  void didUpdateWidget(SchedulePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The adult may edit the board on another screen; keep progress valid.
    if (_done > _steps.length) _done = _steps.length;
  }

  void _say(String text) => unawaited(ref.read(speakerProvider).say(text));

  Future<void> _markDone() async {
    if (_busy || _current == null) return;
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
    final now = _current;
    _say(now == null ? 'All done!' : now.label);
  }

  Future<void> _restart() async {
    setState(() {
      _done = 0;
      _timerFinished = false;
    });
    await ref.read(repositoryProvider).setProgress(widget.board.id, 0);
    final now = _current;
    if (now != null) _say(now.label);
  }

  Future<void> _stepBack() async {
    if (_done == 0) return;
    setState(() {
      _done--;
      _timerFinished = false;
    });
    await ref.read(repositoryProvider).setProgress(widget.board.id, _done);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(currentSettingsProvider);
    final calm = calmMotionOf(context, setting: settings.calmMotion);
    final current = _current;

    return ChildShell(
      header: _ProgressRail(steps: _steps, done: _done),
      actions: [
        if (_done > 0)
          ChildMenuAction(
            icon: Icons.undo_rounded,
            label: 'Go back one step',
            onSelected: _stepBack,
          ),
        ChildMenuAction(
          icon: Icons.replay_rounded,
          label: 'Start again',
          onSelected: _restart,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: calm ? 250 : 550),
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => calm
                    ? FadeTransition(opacity: animation, child: child)
                    : FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween(
                            begin: 0.85,
                            end: 1.0,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                child: current == null
                    ? _AllDone(key: const ValueKey('all-done'), calm: calm)
                    : _NowAndNext(
                        key: ValueKey(current.id),
                        current: current,
                        next: _next,
                        showLabels: settings.showLabels,
                        busy: _busy,
                        timerFinished: _timerFinished,
                        onDone: _markDone,
                        onTimerFinished: () =>
                            setState(() => _timerFinished = true),
                        onSpeak: _say,
                      ),
              ),
            ),
            // Centred on the "Now" card (3/5 of the space, left or top).
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth > c.maxHeight * 1.05;
                return Align(
                  alignment: wide
                      ? const Alignment(-0.4, 0.05)
                      : const Alignment(0, -0.36),
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

class _NowAndNext extends StatelessWidget {
  const _NowAndNext({
    super.key,
    required this.current,
    required this.next,
    required this.showLabels,
    required this.busy,
    required this.timerFinished,
    required this.onDone,
    required this.onTimerFinished,
    required this.onSpeak,
  });

  final BoardStep current;
  final BoardStep? next;
  final bool showLabels;
  final bool busy;
  final bool timerFinished;
  final VoidCallback onDone;
  final VoidCallback onTimerFinished;
  final void Function(String) onSpeak;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > constraints.maxHeight * 1.05;
        final doneSize = (constraints.biggest.shortestSide * 0.16).clamp(
          72.0,
          120.0,
        );
        final duration = current.duration;
        final now = KidCard(
          step: current,
          role: KidCardRole.now,
          tag: 'Now',
          showLabel: showLabels,
          onTap: () => onSpeak(current.label),
          pictureOverride: duration == null
              ? null
              : StepTimer(
                  key: ValueKey('timer-${current.id}'),
                  step: current,
                  duration: duration,
                  onFinished: onTimerFinished,
                ),
          footer: DoneButton(
            onPressed: busy ? null : onDone,
            size: doneSize,
            attention: timerFinished,
          ),
        );
        final upcoming = next == null
            ? const _FinishCard()
            : KidCard(
                step: next!,
                role: KidCardRole.next,
                tag: 'Next',
                showLabel: showLabels,
                onTap: () => onSpeak(next!.label),
              );
        return Flex(
          direction: wide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: now,
              ),
            ),
            SizedBox(width: wide ? 28 : 0, height: wide ? 0 : 28),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.only(
                  top: 14,
                  // Keep the "next" card visibly smaller.
                  bottom: wide ? constraints.maxHeight * 0.12 : 0,
                ),
                child: upcoming,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Shown in the "Next" slot on the last step.
class _FinishCard extends StatelessWidget {
  const _FinishCard();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: KidColors.track, width: 3),
            ),
            child: LayoutBuilder(
              builder: (context, c) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: Brand.sunflower,
                    size: c.biggest.shortestSide * 0.5,
                  ),
                  Text(
                    'All done',
                    style: TextStyle(
                      fontSize: (c.biggest.shortestSide * 0.1).clamp(18, 36),
                      fontWeight: FontWeight.w700,
                      color: KidColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Positioned(left: 20, top: -14, child: KidTag(text: 'Next')),
      ],
    );
  }
}

class _AllDone extends StatefulWidget {
  const _AllDone({super.key, required this.calm});

  final bool calm;

  @override
  State<_AllDone> createState() => _AllDoneState();
}

class _AllDoneState extends State<_AllDone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  int _burst = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.calm) {
      _spin.forward();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _burst++);
      });
    } else {
      _spin.value = 1;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest.shortestSide;
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _spin,
                    builder: (context, child) => Transform.scale(
                      scale: Curves.elasticOut.transform(_spin.value),
                      child: child,
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      size: size * 0.55,
                      color: Brand.sunflower,
                    ),
                  ),
                  Text(
                    'All done!',
                    style: TextStyle(
                      fontSize: (size * 0.12).clamp(32, 72),
                      fontWeight: FontWeight.w700,
                      color: KidColors.text,
                    ),
                  ),
                ],
              ),
              DoneBurst(trigger: _burst, size: size * 0.3),
            ],
          ),
        );
      },
    );
  }
}

/// All steps in a row: finished ones ticked, the current one ringed.
class _ProgressRail extends StatefulWidget {
  const _ProgressRail({required this.steps, required this.done});

  final List<BoardStep> steps;
  final int done;

  @override
  State<_ProgressRail> createState() => _ProgressRailState();
}

class _ProgressRailState extends State<_ProgressRail> {
  final _scroll = ScrollController();
  static const _item = 56.0;
  static const _gap = 10.0;

  @override
  void didUpdateWidget(_ProgressRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.done != widget.done) _scrollToCurrent();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToCurrent(jump: true),
    );
  }

  void _scrollToCurrent({bool jump = false}) {
    if (!_scroll.hasClients) return;
    final target = ((widget.done - 1) * (_item + _gap)).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    if (jump) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _item + 8,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: widget.steps.length,
        separatorBuilder: (_, _) => const SizedBox(width: _gap),
        itemBuilder: (context, i) {
          final step = widget.steps[i];
          final isDone = i < widget.done;
          final isNow = i == widget.done;
          return Semantics(
            label:
                '${step.label}${isDone
                    ? ', done'
                    : isNow
                    ? ', now'
                    : ''}',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _item,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isNow ? KidColors.now : KidColors.track,
                  width: isNow ? 4 : 2,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: isDone ? 0.35 : 1,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: PictureView(
                        picture: step.picture,
                        label: step.label,
                        thumbnailWidth: _item,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (isDone)
                    const Center(
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: KidColors.done,
                        child: Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
