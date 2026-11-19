import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// A small, quiet lock in the corner of the child view. Press and hold it for
/// two seconds, then answer a sum, to get back to the adult screens.
class GateButton extends StatefulWidget {
  const GateButton({
    super.key,
    required this.onUnlocked,
    this.holdTime = const Duration(seconds: 2),
  });

  final VoidCallback onUnlocked;
  final Duration holdTime;

  @override
  State<GateButton> createState() => _GateButtonState();
}

class _GateButtonState extends State<GateButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: widget.holdTime,
  )..addStatusListener(_onStatus);

  void _onStatus(AnimationStatus status) async {
    if (status != AnimationStatus.completed) return;
    unawaited(HapticFeedback.mediumImpact());
    _hold.value = 0;
    final ok = await showAdultCheck(context);
    if (ok && mounted) widget.onUnlocked();
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'For grown-ups: press and hold to unlock',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _hold.forward(from: 0),
        onTapUp: (_) => _cancel(),
        onTapCancel: _cancel,
        child: SizedBox.square(
          dimension: 56,
          child: AnimatedBuilder(
            animation: _hold,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: 40,
                  child: CircularProgressIndicator(
                    value: _hold.value,
                    strokeWidth: 4,
                    color: Brand.teal,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                Icon(
                  Icons.lock_outline_rounded,
                  size: 22,
                  color: KidColors.muted.withValues(
                    alpha: 0.55 + 0.45 * _hold.value,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _cancel() {
    if (_hold.status != AnimationStatus.completed) _hold.reverse();
  }
}

/// Asks a simple sum with an on-screen number pad. Returns true when the
/// answer is right.
Future<bool> showAdultCheck(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _AdultCheckDialog(),
  );
  return result ?? false;
}

class _AdultCheckDialog extends StatefulWidget {
  const _AdultCheckDialog();

  @override
  State<_AdultCheckDialog> createState() => _AdultCheckDialogState();
}

class _AdultCheckDialogState extends State<_AdultCheckDialog> {
  final _random = math.Random();
  late int _a;
  late int _b;
  String _answer = '';
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _newSum();
  }

  void _newSum() {
    _a = 6 + _random.nextInt(4); // 6..9
    _b = 5 + _random.nextInt(5); // 5..9
    _answer = '';
  }

  void _press(String key) {
    setState(() {
      _wrong = false;
      if (key == '⌫') {
        if (_answer.isNotEmpty) {
          _answer = _answer.substring(0, _answer.length - 1);
        }
        return;
      }
      if (_answer.length >= 2) return;
      _answer += key;
      if (_answer.length == 2) {
        if (int.parse(_answer) == _a + _b) {
          Navigator.of(context).pop(true);
        } else {
          _wrong = true;
          HapticFeedback.heavyImpact();
          _newSum();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return AlertDialog(
      title: const Text('For grown-ups'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('What is $_a + $_b?', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Container(
              height: 56,
              width: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _wrong
                      ? theme.colorScheme.error
                      : theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: Text(
                _answer.isEmpty ? (_wrong ? 'Try again' : '') : _answer,
                style: _answer.isEmpty
                    ? theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      )
                    : theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final k in keys)
                  if (k.isEmpty)
                    const SizedBox.shrink()
                  else
                    FilledButton.tonal(
                      onPressed: () => _press(k),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: k == '⌫'
                          ? const Icon(
                              Icons.backspace_outlined,
                              semanticLabel: 'Delete',
                            )
                          : Text(k, style: const TextStyle(fontSize: 22)),
                    ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
