import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/visual_timer.dart';
import 'about_screen.dart';
import 'import_flow.dart';
import 'share_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(currentSettingsProvider);
    final repo = ref.read(repositoryProvider);
    final theme = Theme.of(context);
    Future<void> update(AppSettings Function(AppSettings) change) =>
        repo.updateSettings(change);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const _Header('Child view'),
              SwitchListTile(
                secondary: const Icon(Icons.record_voice_over_outlined),
                title: const Text('Say the words aloud'),
                subtitle: const Text(
                  'Uses the device’s own voice. Tap a card to hear it.',
                ),
                value: s.speechEnabled,
                onChanged: (v) => update((x) => x.copyWith(speechEnabled: v)),
              ),
              ListTile(
                leading: const Icon(Icons.speed_rounded),
                title: const Text('Speaking speed'),
                subtitle: Slider(
                  value: s.speechRate,
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  label: s.speechRate < 0.4
                      ? 'Slow'
                      : (s.speechRate > 0.6 ? 'Fast' : 'Normal'),
                  onChanged: s.speechEnabled
                      ? (v) => update((x) => x.copyWith(speechRate: v))
                      : null,
                ),
                trailing: IconButton(
                  tooltip: 'Test the voice',
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  onPressed: () => ref
                      .read(speakerProvider)
                      .preview('First brush teeth, then story time.'),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.text_fields_rounded),
                title: const Text('Show words under pictures'),
                value: s.showLabels,
                onChanged: (v) => update((x) => x.copyWith(showLabels: v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.motion_photos_off_outlined),
                title: const Text('Calm motion'),
                subtitle: const Text(
                  'Gentle fades instead of bouncy celebrations.',
                ),
                value: s.calmMotion,
                onChanged: (v) => update((x) => x.copyWith(calmMotion: v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.wb_twilight_rounded),
                title: const Text('Start again each morning'),
                subtitle: const Text(
                  'Boards go back to the first step on a new day.',
                ),
                value: s.resetDaily,
                onChanged: (v) => update((x) => x.copyWith(resetDaily: v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.child_care_rounded),
                title: const Text('Open straight to the child view'),
                subtitle: const Text(
                  'For a device that belongs to your child: it opens on the last board you showed. '
                  'Hold the lock in the corner to get back here.',
                ),
                value: s.openInChildMode,
                onChanged: (v) => update((x) => x.copyWith(openInChildMode: v)),
              ),
              const _Header('Visual timer'),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    for (final style in TimerStyle.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _TimerStyleOption(
                            style: style,
                            color: Color(s.timerColor),
                            selected: s.timerStyle == style,
                            onTap: () =>
                                update((x) => x.copyWith(timerStyle: style)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final c in timerColorChoices)
                      Semantics(
                        button: true,
                        selected: s.timerColor == c,
                        label: 'Timer colour',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => update((x) => x.copyWith(timerColor: c)),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: s.timerColor == c
                                    ? theme.colorScheme.onSurface
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: s.timerColor == c
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.pin_outlined),
                title: const Text('Show minutes left as numbers'),
                subtitle: const Text(
                  'Off by default — the shrinking disc is easier to read.',
                ),
                value: s.showTimeLeft,
                onChanged: (v) => update((x) => x.copyWith(showTimeLeft: v)),
              ),
              const _Header('Your boards'),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Back up all boards'),
                subtitle: const Text(
                  'Saves one .daysteps file with every board and photo.',
                ),
                onTap: () async {
                  final boards = await repo.getBoards();
                  if (!context.mounted) return;
                  await saveBoardsToFile(
                    context,
                    ref,
                    [for (final b in boards) b.id],
                    'daysteps-backup-${DateTime.now().toIso8601String().substring(0, 10)}',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Import or restore'),
                subtitle: const Text('From a file, QR code or link.'),
                onTap: () => showImportSheet(context, ref),
              ),
              const _Header('About'),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('About Daysteps'),
                subtitle: const Text(
                  'Version, privacy, picture credits and licences',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimerStyleOption extends StatelessWidget {
  const _TimerStyleOption({
    required this.style,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final TimerStyle style;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox.square(
                  dimension: 72,
                  child: CustomPaint(
                    painter: TimerDiscPainter(
                      fraction: 0.6,
                      color: color,
                      style: style,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  style == TimerStyle.pie ? 'Sweeping disc' : 'Shrinking disc',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
