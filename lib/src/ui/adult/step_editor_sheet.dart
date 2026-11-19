import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/picture_view.dart';
import '../widgets/visual_timer.dart';
import 'picture_picker.dart';

/// The result of editing a card.
sealed class StepEdit {
  const StepEdit();
}

class StepSaved extends StepEdit {
  const StepSaved(this.label, this.picture, this.duration);
  final String label;
  final PictureRef? picture;
  final Duration? duration;
}

class StepDeleted extends StepEdit {
  const StepDeleted();
}

const _timerChoices = <int?>[null, 1, 2, 3, 5, 10, 15, 20, 30];

/// Edits one card: picture, words and optional timer.
Future<StepEdit?> showStepEditor(
  BuildContext context, {
  required String title,
  String label = '',
  PictureRef? picture,
  Duration? duration,
  bool canDelete = true,
}) {
  return showModalBottomSheet<StepEdit>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _StepEditor(
      title: title,
      label: label,
      picture: picture,
      duration: duration,
      canDelete: canDelete,
    ),
  );
}

class _StepEditor extends ConsumerStatefulWidget {
  const _StepEditor({
    required this.title,
    required this.label,
    required this.picture,
    required this.duration,
    required this.canDelete,
  });

  final String title;
  final String label;
  final PictureRef? picture;
  final Duration? duration;
  final bool canDelete;

  @override
  ConsumerState<_StepEditor> createState() => _StepEditorState();
}

class _StepEditorState extends ConsumerState<_StepEditor> {
  late final _label = TextEditingController(text: widget.label);
  late PictureRef? _picture = widget.picture;
  late Duration? _duration = widget.duration;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _choosePicture() async {
    final picked = await pickPicture(
      context,
      initialQuery: _picture == null ? _label.text : '',
    );
    if (picked == null) return;
    setState(() {
      // Use the picture's name unless the adult already typed their own words.
      final current = _label.text.trim();
      if (current.isEmpty || current == _pictureName()) {
        _label.text = picked.label;
      }
      _picture = picked.picture;
    });
  }

  String? _pictureName() {
    final p = _picture;
    if (p is SymbolPicture) {
      return ref.read(symbolCatalogProvider)[p.symbolId]?.label;
    }
    return null;
  }

  Future<void> _customDuration() async {
    var minutes = (_duration?.inMinutes ?? 5).clamp(1, 120).toDouble();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Timer length'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${minutes.round()} min',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Slider(
                value: minutes,
                min: 1,
                max: 120,
                divisions: 119,
                onChanged: (v) => setDialogState(() => minutes = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, minutes.round()),
              child: const Text('Set'),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _duration = Duration(minutes: result));
  }

  void _save() {
    final label = _label.text.trim();
    if (label.isEmpty && _picture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a picture or some words.')),
      );
      return;
    }
    Navigator.pop(context, StepSaved(label, _picture, _duration));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _duration;
    final isPreset =
        d == null ||
        (d.inSeconds % 60 == 0 && _timerChoices.contains(d.inMinutes));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Center(
              child: Semantics(
                button: true,
                label: 'Change picture',
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: _choosePicture,
                  child: Container(
                    width: 180,
                    height: 180,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: _picture == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 56,
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
                        : PictureView(
                            picture: _picture,
                            label: _label.text,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ),
            ),
            if (_picture != null)
              Center(
                child: TextButton.icon(
                  onPressed: _choosePicture,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Change picture'),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Words on the card',
                hintText: 'e.g. Brush teeth',
                suffixIcon: IconButton(
                  tooltip: 'Hear it',
                  icon: const Icon(Icons.volume_up_rounded),
                  onPressed: () =>
                      ref.read(speakerProvider).preview(_label.text),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            Text('Visual timer', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _timerChoices)
                  ChoiceChip(
                    label: Text(m == null ? 'No timer' : '$m min'),
                    selected: m == null
                        ? _duration == null
                        : _duration == Duration(minutes: m),
                    onSelected: (_) => setState(
                      () => _duration = m == null ? null : Duration(minutes: m),
                    ),
                  ),
                ChoiceChip(
                  label: Text(
                    !isPreset && _duration != null
                        ? formatDuration(_duration!)
                        : 'Other…',
                  ),
                  selected: !isPreset && _duration != null,
                  onSelected: (_) => _customDuration(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.canDelete)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () =>
                        Navigator.pop(context, const StepDeleted()),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
