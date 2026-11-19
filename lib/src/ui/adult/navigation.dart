import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../child/child_mode_screen.dart';
import '../child/timer_screen.dart';
import 'board_editor_screen.dart';

/// Shows [boardId] to the child and remembers it as the active board.
Future<void> openChildMode(
  BuildContext context,
  WidgetRef ref,
  String boardId,
) async {
  final repo = ref.read(repositoryProvider);
  final navigator = Navigator.of(context);
  await repo.updateSettings((s) => s.copyWith(activeBoardId: boardId));
  await navigator.push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ChildModeScreen(boardId: boardId),
    ),
  );
}

Future<void> openTimer(
  BuildContext context, {
  required Duration duration,
  PictureRef? picture,
  String label = '',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          TimerScreen(duration: duration, picture: picture, label: label),
    ),
  );
}

Future<void> openEditor(BuildContext context, String boardId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BoardEditorScreen(boardId: boardId),
    ),
  );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Asks before something destructive. Returns true to go ahead.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Asks for a short piece of text (a board title, a picture name).
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  String action = 'Save',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _TextPrompt(title: title, initial: initial, hint: hint, action: action),
  );
}

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.initial,
    required this.hint,
    required this.action,
  });

  final String title;
  final String initial;
  final String hint;
  final String action;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}
