import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models.dart';
import '../../share/board_codec.dart';
import '../../share/transfer.dart';
import '../../state/providers.dart';
import '../widgets/qr_code_view.dart';
import 'navigation.dart';

/// Share one board with another device: as a file, or as a QR code.
Future<void> showShareSheet(BuildContext context, WidgetRef ref, Board board) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => _ShareSheet(board: board),
  );
}

class _ShareSheet extends ConsumerWidget {
  const _ShareSheet({required this.board});

  final Board board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Share “${board.title}”',
                style: theme.textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2_rounded),
              title: const Text('Show a QR code'),
              subtitle: const Text(
                'Scan it with the other device. Photos are not included.',
              ),
              onTap: () {
                Navigator.pop(context);
                showQrDialog(context, board);
              },
            ),
            ListTile(
              leading: const Icon(Icons.send_rounded),
              title: const Text('Send as a file'),
              subtitle: const Text(
                'Email, messages, Drive… Includes your photos.',
              ),
              onTap: () async {
                Navigator.pop(context);
                await shareBoardsAsFile(context, ref, [board.id], board.title);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: const Text('Save file to this device'),
              subtitle: const Text(
                'A .daysteps file you can open on another device.',
              ),
              onTap: () async {
                Navigator.pop(context);
                await saveBoardsToFile(context, ref, [board.id], board.title);
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<Uint8List> _encode(WidgetRef ref, List<String> boardIds) async {
  final package = await ref.read(transferProvider).export(boardIds);
  String? version;
  try {
    version = (await PackageInfo.fromPlatform()).version;
  } catch (_) {}
  return BoardCodec.encodeFile(package, appVersion: version);
}

/// Opens the system share sheet with a `.daysteps` file.
Future<void> shareBoardsAsFile(
  BuildContext context,
  WidgetRef ref,
  List<String> boardIds,
  String name,
) async {
  final bytes = await _encode(ref, boardIds);
  final fileName = BoardCodec.fileNameFor(name);
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: BoardCodec.mimeType, name: fileName),
        ],
        fileNameOverrides: [fileName],
        subject: 'Daysteps: $name',
        downloadFallbackEnabled: true,
      ),
    );
  } catch (e) {
    if (context.mounted) showMessage(context, 'Could not share the file.');
  }
}

/// Saves a `.daysteps` file with the platform's save dialog (or a download
/// on the web).
Future<void> saveBoardsToFile(
  BuildContext context,
  WidgetRef ref,
  List<String> boardIds,
  String name,
) async {
  final bytes = await _encode(ref, boardIds);
  try {
    final uri = await FilePicker.saveFile(
      fileName: BoardCodec.fileNameFor(name),
      bytes: bytes,
      mimeType: BoardCodec.mimeType,
      dialogTitle: 'Save board',
    );
    if (uri != null && context.mounted && !kIsWeb) {
      showMessage(context, 'Saved.');
    }
  } catch (e) {
    if (context.mounted) showMessage(context, 'Could not save the file.');
  }
}

/// Shows a board as a QR code (a link to the Daysteps web app, so any phone
/// camera can open it).
Future<void> showQrDialog(BuildContext context, Board board) {
  final link = BoardCodec.encodeLink(BoardTransfer.toShared(board));
  final tooLong = link.length > BoardCodec.maxQrLength;
  final hasPhotos = board.steps.any((s) => s.picture is StoredPicture);
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: Text(board.title),
        content: SizedBox(
          width: 320,
          child: tooLong
              ? const Text(
                  'This board is too long for a QR code. Send it as a file instead.',
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrCodeView(data: link, size: 280),
                    const SizedBox(height: 12),
                    Text(
                      'In Daysteps on the other device, tap Import → Scan a QR code. '
                      'Or scan with any camera to open it in the web app.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (hasPhotos)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Photos are not in QR codes: those cards will show their words. Send a file to include photos.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          if (!tooLong)
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (context.mounted) showMessage(context, 'Link copied.');
              },
              icon: const Icon(Icons.link_rounded),
              label: const Text('Copy link'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}
