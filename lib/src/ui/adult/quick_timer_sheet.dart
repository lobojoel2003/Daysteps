import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/picture_view.dart';
import '../widgets/visual_timer.dart';
import 'navigation.dart';
import 'picture_picker.dart';

const _presets = [1, 2, 3, 5, 10, 15, 20, 30];

/// "Visual timer" panel on the home screen: one tap starts a full-screen
/// timer for the child.
class QuickTimerPanel extends ConsumerWidget {
  const QuickTimerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = Color(
      ref.watch(currentSettingsProvider.select((s) => s.timerColor)),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 72,
              child: CustomPaint(
                painter: TimerDiscPainter(
                  fraction: 0.7,
                  color: color,
                  style: TimerStyle.pie,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visual timer',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A coloured disc that shrinks as time passes. Tap a time to start.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in _presets)
                        ActionChip(
                          label: Text('$m min'),
                          onPressed: () => openTimer(
                            context,
                            duration: Duration(minutes: m),
                          ),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('More…'),
                        onPressed: () async {
                          final config =
                              await showModalBottomSheet<_TimerConfig>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => const _CustomTimerSheet(),
                              );
                          if (config == null || !context.mounted) return;
                          await openTimer(
                            context,
                            duration: config.duration,
                            picture: config.picture?.picture,
                            label: config.picture?.label ?? '',
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerConfig {
  const _TimerConfig(this.duration, this.picture);
  final Duration duration;
  final PickedPicture? picture;
}

class _CustomTimerSheet extends ConsumerStatefulWidget {
  const _CustomTimerSheet();

  @override
  ConsumerState<_CustomTimerSheet> createState() => _CustomTimerSheetState();
}

class _CustomTimerSheetState extends ConsumerState<_CustomTimerSheet> {
  double _minutes = 5;
  PickedPicture? _picture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = _minutes.round();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Visual timer', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '$minutes ${minutes == 1 ? 'minute' : 'minutes'}',
              style: theme.textTheme.headlineMedium,
            ),
            Slider(
              value: _minutes,
              min: 1,
              max: 60,
              divisions: 59,
              label: '$minutes min',
              onChanged: (v) => setState(() => _minutes = v),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox.square(
                dimension: 56,
                child: _picture == null
                    ? const Icon(Icons.add_photo_alternate_outlined, size: 32)
                    : PictureView(
                        picture: _picture!.picture,
                        label: _picture!.label,
                      ),
              ),
              title: Text(
                _picture == null ? 'Add a picture (optional)' : _picture!.label,
              ),
              subtitle: const Text('Shown in the middle of the timer'),
              trailing: _picture == null
                  ? null
                  : IconButton(
                      tooltip: 'Remove picture',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _picture = null),
                    ),
              onTap: () async {
                final picked = await pickPicture(context);
                if (picked != null) setState(() => _picture = picked);
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                _TimerConfig(Duration(minutes: minutes), _picture),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start timer'),
            ),
          ],
        ),
      ),
    );
  }
}
