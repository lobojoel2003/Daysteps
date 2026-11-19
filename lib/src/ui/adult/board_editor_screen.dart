import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/picture_view.dart';
import '../widgets/visual_timer.dart';
import 'navigation.dart';
import 'picture_picker.dart';
import 'share_sheet.dart';
import 'step_editor_sheet.dart';

/// Where the adult builds a board. Steps are reordered by drag and drop; on
/// wide screens pictures can be dragged straight from the library.
class BoardEditorScreen extends ConsumerWidget {
  const BoardEditorScreen({super.key, required this.boardId});

  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(boardProvider(boardId));
    final board = async.value;
    if (board == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: async.isLoading
              ? const CircularProgressIndicator()
              : const Text('This board was deleted.'),
        ),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final isSchedule = board.kind == BoardKind.schedule;

    final editor = isSchedule
        ? _ScheduleEditor(board: board, wide: wide)
        : _FirstThenEditor(board: board);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          button: true,
          label: 'Rename board',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _rename(context, ref, board),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(board.title, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined, size: 18),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => showShareSheet(context, ref, board),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) async {
              final repo = ref.read(repositoryProvider);
              if (value == 'duplicate') {
                final id = await repo.duplicateBoard(board.id);
                if (id != null && context.mounted) {
                  showMessage(context, 'Copied “${board.title}”.');
                }
              } else if (value == 'delete') {
                final ok = await confirm(
                  context,
                  title: 'Delete “${board.title}”?',
                  message: 'The board and its steps will be removed from this device.',
                  action: 'Delete',
                );
                if (ok && context.mounted) {
                  Navigator.pop(context);
                  await repo.deleteBoard(board.id);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'duplicate',
                child: ListTile(
                  leading: Icon(Icons.copy_rounded),
                  title: Text('Duplicate'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Delete'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: board.isPlayable
          ? FloatingActionButton.extended(
              heroTag: 'show',
              onPressed: () => openChildMode(context, ref, board.id),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Show to child'),
            )
          : null,
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: editor),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 400,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Text(
                          'Drag a picture onto the board',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: SymbolBrowser(
                          draggable: true,
                          tileExtent: 112,
                          onPicked: (s) => _addFromPalette(
                            ref,
                            board,
                            PickedPicture(
                              picture: SymbolPicture(s.id),
                              label: s.label,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : editor,
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Board board) async {
    final title = await promptText(
      context,
      title: 'Rename board',
      initial: board.title,
    );
    if (title != null) {
      await ref.read(repositoryProvider).renameBoard(board.id, title);
    }
  }

  /// Tapping a palette tile adds it to the end (schedule) or the first empty
  /// slot (first–then).
  Future<void> _addFromPalette(
    WidgetRef ref,
    Board board,
    PickedPicture p,
  ) async {
    final repo = ref.read(repositoryProvider);
    if (board.kind == BoardKind.schedule) {
      await repo.addStep(
        board.id,
        StepDraft(label: p.label, picture: p.picture),
      );
      return;
    }
    final target = board.steps.firstWhere(
      (s) => s.picture == null && s.label.isEmpty,
      orElse: () => board.steps.last,
    );
    await repo.updateStep(
      board.id,
      target.copyWith(label: p.label, picture: p.picture),
    );
  }
}

// -----------------------------------------------------------------------------
// Schedules
// -----------------------------------------------------------------------------

class _ScheduleEditor extends ConsumerStatefulWidget {
  const _ScheduleEditor({required this.board, required this.wide});

  final Board board;
  final bool wide;

  @override
  ConsumerState<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends ConsumerState<_ScheduleEditor> {
  late List<BoardStep> _steps = widget.board.steps;
  bool _dropHover = false;

  @override
  void didUpdateWidget(_ScheduleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _steps = widget.board.steps;
  }

  Future<void> _add({int? index}) async {
    final edit = await showStepEditor(
      context,
      title: 'New step',
      canDelete: false,
    );
    if (edit is! StepSaved) return;
    await ref
        .read(repositoryProvider)
        .addStep(
          widget.board.id,
          StepDraft(
            label: edit.label,
            picture: edit.picture,
            duration: edit.duration,
          ),
          index: index,
        );
  }

  Future<void> _edit(BoardStep step) async {
    final edit = await showStepEditor(
      context,
      title: 'Edit step',
      label: step.label,
      picture: step.picture,
      duration: step.duration,
    );
    final repo = ref.read(repositoryProvider);
    switch (edit) {
      case StepSaved(:final label, :final picture, :final duration):
        await repo.updateStep(
          widget.board.id,
          BoardStep(
            id: step.id,
            label: label,
            picture: picture,
            duration: duration,
          ),
        );
      case StepDeleted():
        await _delete(step);
      case null:
        break;
    }
  }

  Future<void> _delete(BoardStep step) async {
    final repo = ref.read(repositoryProvider);
    final index = _steps.indexOf(step);
    await repo.deleteStep(widget.board.id, step.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Deleted “${step.label.isEmpty ? 'step' : step.label}”.',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.addStep(
              widget.board.id,
              StepDraft(
                label: step.label,
                picture: step.picture,
                duration: step.duration,
              ),
              index: index,
            ),
          ),
        ),
      );
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final list = [..._steps];
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      _steps = list;
    });
    unawaited(
      ref
          .read(repositoryProvider)
          .moveStep(widget.board.id, oldIndex, newIndex),
    );
  }

  Future<void> _drop(PickedPicture p, {int? index}) async {
    await ref
        .read(repositoryProvider)
        .addStep(
          widget.board.id,
          StepDraft(label: p.label, picture: p.picture),
          index: index,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<PickedPicture>(
      onWillAcceptWithDetails: (_) {
        setState(() => _dropHover = true);
        return true;
      },
      onLeave: (_) => setState(() => _dropHover = false),
      onAcceptWithDetails: (details) {
        setState(() => _dropHover = false);
        _drop(details.data);
      },
      builder: (context, _, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _dropHover
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : Colors.transparent,
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          buildDefaultDragHandles: false,
          header: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
            child: Text(
              _steps.isEmpty
                  ? 'Add the steps of the routine in order. Each step is a picture with a few words.'
                  : 'Tap a step to change it. Drag the handle to change the order.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          footer: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _add,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add step'),
              ),
            ),
          ),
          itemCount: _steps.length,
          onReorderItem: _reorder,
          proxyDecorator: (child, _, animation) => Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            color: Colors.transparent,
            child: child,
          ),
          itemBuilder: (context, i) {
            final step = _steps[i];
            return Padding(
              key: ValueKey(step.id),
              padding: const EdgeInsets.only(bottom: 10),
              child: DragTarget<PickedPicture>(
                onAcceptWithDetails: (d) => _drop(d.data, index: i),
                builder: (context, candidates, _) => Column(
                  children: [
                    if (candidates.isNotEmpty)
                      Container(
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    _StepTile(
                      index: i,
                      step: step,
                      onTap: () => _edit(step),
                      onDelete: () => _delete(step),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.step,
    required this.onTap,
    required this.onDelete,
  });

  final int index;
  final BoardStep step;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = step.duration;
    return ReorderableDelayedDragStartListener(
      index: index,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      semanticLabel: 'Drag to reorder',
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: PictureView(
                    picture: step.picture,
                    label: step.label,
                    thumbnailWidth: 72,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.label.isEmpty ? '(no words)' : step.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (duration != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timelapse_rounded,
                                size: 16,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formatDuration(duration),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete step',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// First–then boards
// -----------------------------------------------------------------------------

class _FirstThenEditor extends ConsumerStatefulWidget {
  const _FirstThenEditor({required this.board});

  final Board board;

  @override
  ConsumerState<_FirstThenEditor> createState() => _FirstThenEditorState();
}

class _FirstThenEditorState extends ConsumerState<_FirstThenEditor> {
  @override
  void initState() {
    super.initState();
    _ensureTwoSlots();
  }

  Future<void> _ensureTwoSlots() async {
    final missing = 2 - widget.board.steps.length;
    for (var i = 0; i < missing; i++) {
      await ref
          .read(repositoryProvider)
          .addStep(widget.board.id, const StepDraft(label: ''));
    }
  }

  Future<void> _edit(BoardStep step, String slot) async {
    final edit = await showStepEditor(
      context,
      title: slot,
      label: step.label,
      picture: step.picture,
      duration: step.duration,
      canDelete: false,
    );
    if (edit is StepSaved) {
      await ref
          .read(repositoryProvider)
          .updateStep(
            widget.board.id,
            BoardStep(
              id: step.id,
              label: edit.label,
              picture: edit.picture,
              duration: edit.duration,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = widget.board.steps;
    if (steps.length < 2) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Text(
          'Pick what happens first (often the harder thing) and what comes after it (something your child enjoys).',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 560;
            final first = _Slot(
              boardId: widget.board.id,
              step: steps[0],
              title: 'First',
              onTap: () => _edit(steps[0], 'First'),
            );
            final then = _Slot(
              boardId: widget.board.id,
              step: steps[1],
              title: 'Then',
              onTap: () => _edit(steps[1], 'Then'),
            );
            final arrow = Icon(
              wide ? Icons.arrow_forward_rounded : Icons.arrow_downward_rounded,
              size: 40,
              color: theme.colorScheme.outline,
            );
            return wide
                ? Row(
                    children: [
                      Expanded(child: first),
                      Padding(padding: const EdgeInsets.all(12), child: arrow),
                      Expanded(child: then),
                    ],
                  )
                : Column(
                    children: [
                      first,
                      Padding(padding: const EdgeInsets.all(8), child: arrow),
                      then,
                    ],
                  );
          },
        ),
      ],
    );
  }
}

class _Slot extends ConsumerWidget {
  const _Slot({
    required this.boardId,
    required this.step,
    required this.title,
    required this.onTap,
  });

  final String boardId;
  final BoardStep step;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final empty = step.picture == null && step.label.isEmpty;
    final duration = step.duration;
    return DragTarget<PickedPicture>(
      onAcceptWithDetails: (d) => ref
          .read(repositoryProvider)
          .updateStep(
            boardId,
            step.copyWith(label: d.data.label, picture: d.data.picture),
          ),
      builder: (context, candidates, _) => Card(
        color: candidates.isNotEmpty
            ? theme.colorScheme.primaryContainer
            : null,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 1.2,
                  child: empty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 64,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose a picture',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : PictureView(picture: step.picture, label: step.label),
                ),
                const SizedBox(height: 12),
                Text(
                  empty ? ' ' : step.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (duration != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Timer: ${formatDuration(duration)}',
                      style: TextStyle(color: theme.colorScheme.secondary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
