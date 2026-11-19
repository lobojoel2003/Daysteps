import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/models.dart';
import '../../share/board_codec.dart';
import '../../state/providers.dart';
import 'navigation.dart';

/// Lets the adult bring in a board from a file, a QR code or a pasted link.
Future<void> showImportSheet(BuildContext context, WidgetRef ref) async {
  final choice = await showModalBottomSheet<_ImportSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Import a board',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded),
              title: const Text('Scan a QR code'),
              onTap: () => Navigator.pop(context, _ImportSource.scan),
            ),
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: const Text('Open a .daysteps file'),
              onTap: () => Navigator.pop(context, _ImportSource.file),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste_rounded),
              title: const Text('Paste a link or code'),
              onTap: () => Navigator.pop(context, _ImportSource.paste),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _ImportSource.file:
      await _importFile(context, ref);
    case _ImportSource.scan:
      final text = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const QrScanScreen(),
        ),
      );
      if (text != null && context.mounted) {
        await importFromText(context, ref, text);
      }
    case _ImportSource.paste:
      final text = await promptText(
        context,
        title: 'Paste a link or code',
        hint: '${BoardCodec.webAppUrl}#import=DS1.…',
        action: 'Import',
      );
      if (text != null && context.mounted) {
        await importFromText(context, ref, text);
      }
  }
}

enum _ImportSource { file, scan, paste }

Future<void> _importFile(BuildContext context, WidgetRef ref) async {
  try {
    final file = await FilePicker.pickFile(
      type: FileType.any,
      dialogTitle: 'Open a Daysteps file',
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final package = BoardCodec.decodeFile(bytes);
    if (context.mounted) await _confirmAndImport(context, ref, package);
  } on BoardFormatException catch (e) {
    if (context.mounted) showMessage(context, e.message);
  } catch (e) {
    if (context.mounted) showMessage(context, 'Could not open that file.');
  }
}

/// Imports a board from QR text or a link.
Future<void> importFromText(
  BuildContext context,
  WidgetRef ref,
  String text,
) async {
  try {
    final board = BoardCodec.decodeQr(text);
    await _confirmAndImport(context, ref, SharedPackage(boards: [board]));
  } on BoardFormatException catch (e) {
    if (context.mounted) showMessage(context, e.message);
  }
}

Future<void> _confirmAndImport(
  BuildContext context,
  WidgetRef ref,
  SharedPackage package,
) async {
  final missing = package.missingPictureCount;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: Text(
          package.boards.length == 1
              ? 'Add this board?'
              : 'Add ${package.boards.length} boards?',
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final b in package.boards.take(6))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    b.kind == BoardKind.schedule
                        ? Icons.view_timeline_rounded
                        : Icons.compare_arrows_rounded,
                  ),
                  title: Text(b.title),
                  subtitle: Text(
                    b.kind == BoardKind.schedule
                        ? '${b.steps.length} steps'
                        : 'First–then',
                  ),
                ),
              if (package.boards.length > 6)
                Text('…and ${package.boards.length - 6} more'),
              if (missing > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$missing ${missing == 1 ? 'card uses a photo' : 'cards use photos'} that '
                    'did not come along; ${missing == 1 ? 'it' : 'they'} will show words instead.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      );
    },
  );
  if (ok != true || !context.mounted) return;
  final ids = await ref.read(transferProvider).import(package);
  if (!context.mounted || ids.isEmpty) return;
  if (ids.length == 1) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Added “${package.boards.first.title}”.'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => openEditor(context, ids.first),
          ),
        ),
      );
  } else {
    showMessage(context, 'Added ${ids.length} boards.');
  }
}

/// A camera view that returns the first Daysteps code it sees.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;
  String? _hint;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final code in capture.barcodes) {
      final value = code.rawValue;
      if (value == null) continue;
      if (BoardCodec.looksLikeQr(value)) {
        _done = true;
        Navigator.pop(context, value);
        return;
      }
      setState(() => _hint = 'That QR code is not a Daysteps board.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan a QR code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  kIsWeb
                      ? 'The camera is not available. Allow camera access in the browser, or paste the link instead.'
                      : 'The camera is not available. Allow camera access for Daysteps in Settings, or paste the link instead.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              _hint ?? 'Point the camera at the QR code on the other device.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
