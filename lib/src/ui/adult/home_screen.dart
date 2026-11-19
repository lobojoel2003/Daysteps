import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/picture_view.dart';
import 'import_flow.dart';
import 'navigation.dart';
import 'quick_timer_sheet.dart';
import 'settings_screen.dart';
import 'share_sheet.dart';

/// The adult's home: all boards, a quick visual timer, import and settings.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _newBoard(BuildContext context, WidgetRef ref) async {
    final kind = await showModalBottomSheet<BoardKind>(
      context: context,
      builder: (context) => const _NewBoardSheet(),
    );
    if (kind == null || !context.mounted) return;
    final title = await promptText(
      context,
      title: kind == BoardKind.schedule
          ? 'New schedule'
          : 'New first–then board',
      hint: kind == BoardKind.schedule
          ? 'e.g. Morning'
          : 'e.g. Homework, then tablet',
      action: 'Create',
    );
    if (title == null || !context.mounted) return;
    final repo = ref.read(repositoryProvider);
    final id = await repo.createBoard(
      title: title,
      kind: kind,
      steps: kind == BoardKind.firstThen
          ? const [StepDraft(label: ''), StepDraft(label: '')]
          : const [],
    );
    if (context.mounted) await openEditor(context, id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boards = ref.watch(boardsProvider);
    final activeId = ref.watch(
      currentSettingsProvider.select((s) => s.activeBoardId),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            BrandMark(size: 34),
            SizedBox(width: 12),
            Text('Daysteps'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Import a board',
            icon: const Icon(Icons.download_rounded),
            onPressed: () => showImportSheet(context, ref),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newBoard(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New board'),
      ),
      body: boards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load boards: $e')),
        data: (list) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  list.isEmpty
                      ? 'Make a board, then tap “Show” to hand the device to your child.'
                      : 'Tap “Show” to hand the device to your child. Hold the lock in the corner to come back.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(onCreate: () => _newBoard(context, ref)),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 460,
                    mainAxisExtent: 236,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => BoardCard(
                      board: list[i],
                      active: list[i].id == activeId,
                    ),
                    childCount: list.length,
                  ),
                ),
              ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 112),
              sliver: SliverToBoxAdapter(child: QuickTimerPanel()),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewBoardSheet extends StatelessWidget {
  const _NewBoardSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What would you like to make?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _KindTile(
              icon: Icons.view_timeline_rounded,
              title: 'Schedule',
              subtitle:
                  'Steps in order: what is happening now, and what comes next.',
              onTap: () => Navigator.pop(context, BoardKind.schedule),
            ),
            const SizedBox(height: 8),
            _KindTile(
              icon: Icons.compare_arrows_rounded,
              title: 'First–then board',
              subtitle: 'Two cards: first this, then that.',
              onTap: () => Navigator.pop(context, BoardKind.firstThen),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, color: scheme.onPrimaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 96),
            const SizedBox(height: 16),
            Text(
              'No boards yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Make your first board'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A board on the home screen.
class BoardCard extends ConsumerWidget {
  const BoardCard({super.key, required this.board, required this.active});

  final Board board;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSchedule = board.kind == BoardKind.schedule;
    final count = board.steps.length;
    final subtitle = isSchedule
        ? '$count ${count == 1 ? 'step' : 'steps'}'
        : 'First–then';

    return Card(
      child: InkWell(
        onTap: () => openEditor(context, board.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSchedule
                        ? Icons.view_timeline_rounded
                        : Icons.compare_arrows_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Brand.sunflower.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'On child view',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                  const Spacer(),
                  _BoardMenu(board: board),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  board.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(child: _Thumbnails(board: board)),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: board.isPlayable
                        ? () => openChildMode(context, ref, board.id)
                        : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Show'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => openEditor(context, board.id),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnails extends StatelessWidget {
  const _Thumbnails({required this.board});

  final Board board;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (board.steps.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'No steps yet — tap Edit to add pictures.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final size = constraints.maxHeight;
        final fit = ((constraints.maxWidth + gap) / (size + gap)).floor().clamp(
          1,
          12,
        );
        final steps = board.steps.take(fit).toList();
        return Row(
          children: [
            for (final (i, s) in steps.indexed) ...[
              if (i > 0)
                board.kind == BoardKind.firstThen
                    ? Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: scheme.outline,
                      )
                    : const SizedBox(width: gap),
              Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: PictureView(
                  picture: s.picture,
                  label: s.label,
                  thumbnailWidth: size,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

enum _BoardAction { show, share, rename, duplicate, delete }

class _BoardMenu extends ConsumerWidget {
  const _BoardMenu({required this.board});

  final Board board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_BoardAction>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) async {
        final repo = ref.read(repositoryProvider);
        switch (action) {
          case _BoardAction.show:
            await openChildMode(context, ref, board.id);
          case _BoardAction.share:
            await showShareSheet(context, ref, board);
          case _BoardAction.rename:
            final title = await promptText(
              context,
              title: 'Rename board',
              initial: board.title,
            );
            if (title != null) await repo.renameBoard(board.id, title);
          case _BoardAction.duplicate:
            await repo.duplicateBoard(board.id);
            if (context.mounted) {
              showMessage(context, 'Copied “${board.title}”.');
            }
          case _BoardAction.delete:
            final ok = await confirm(
              context,
              title: 'Delete “${board.title}”?',
              message: 'The board and its steps will be removed from this device. Photos stay in your library.',
              action: 'Delete',
            );
            if (ok) await repo.deleteBoard(board.id);
        }
      },
      itemBuilder: (context) => [
        if (board.isPlayable)
          const PopupMenuItem(
            value: _BoardAction.show,
            child: ListTile(
              leading: Icon(Icons.play_arrow_rounded),
              title: Text('Show to child'),
            ),
          ),
        const PopupMenuItem(
          value: _BoardAction.share,
          child: ListTile(
            leading: Icon(Icons.ios_share_rounded),
            title: Text('Share'),
          ),
        ),
        const PopupMenuItem(
          value: _BoardAction.rename,
          child: ListTile(
            leading: Icon(Icons.drive_file_rename_outline_rounded),
            title: Text('Rename'),
          ),
        ),
        const PopupMenuItem(
          value: _BoardAction.duplicate,
          child: ListTile(
            leading: Icon(Icons.copy_rounded),
            title: Text('Duplicate'),
          ),
        ),
        const PopupMenuItem(
          value: _BoardAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('Delete'),
          ),
        ),
      ],
    );
  }
}
