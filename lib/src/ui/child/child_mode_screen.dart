import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../theme.dart';
import 'child_shell.dart';
import 'first_then_player.dart';
import 'schedule_player.dart';

/// The child's view of one board.
class ChildModeScreen extends ConsumerStatefulWidget {
  const ChildModeScreen({super.key, required this.boardId});

  final String boardId;

  @override
  ConsumerState<ChildModeScreen> createState() => _ChildModeScreenState();
}

class _ChildModeScreenState extends ConsumerState<ChildModeScreen> {
  int? _initialDone;

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(boardProvider(widget.boardId));
    final progress = ref.watch(progressProvider(widget.boardId));
    _initialDone ??= progress.value;

    final b = board.value;
    if (board.isLoading && b == null || _initialDone == null) {
      return const Scaffold(backgroundColor: KidColors.background);
    }
    if (b == null || !b.isPlayable) {
      return ChildShell(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              b == null
                  ? 'This board is no longer here.'
                  : 'This board has no pictures yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, color: KidColors.text),
            ),
          ),
        ),
      );
    }
    return switch (b.kind) {
      BoardKind.schedule => SchedulePlayer(
        key: ValueKey(b.id),
        board: b,
        initialDone: _initialDone!,
      ),
      BoardKind.firstThen => FirstThenPlayer(
        key: ValueKey(b.id),
        board: b,
        initialDone: _initialDone!,
      ),
    };
  }
}
