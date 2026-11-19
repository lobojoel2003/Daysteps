import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../services/arasaac.dart';
import '../services/speech.dart';
import '../share/transfer.dart';
import '../symbols/symbol_catalog.dart';

/// Overridden in `main()` with the opened repository.
final repositoryProvider = Provider<DaystepsRepository>(
  (ref) => throw UnimplementedError('repositoryProvider must be overridden'),
);

/// Overridden in `main()` with the loaded catalogue.
final symbolCatalogProvider = Provider<SymbolCatalog>(
  (ref) => SymbolCatalog.empty,
);

final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(repositoryProvider).watchSettings(),
);

/// Current settings, or defaults while they load.
final currentSettingsProvider = Provider<AppSettings>(
  (ref) => ref.watch(settingsProvider).value ?? const AppSettings(),
);

final boardsProvider = StreamProvider<List<Board>>(
  (ref) => ref.watch(repositoryProvider).watchBoards(),
);

final boardProvider = StreamProvider.family<Board?, String>(
  (ref, id) => ref.watch(repositoryProvider).watchBoard(id),
);

final progressProvider = StreamProvider.family<int, String>((ref, boardId) {
  final resetDaily = ref.watch(
    currentSettingsProvider.select((s) => s.resetDaily),
  );
  return ref
      .watch(repositoryProvider)
      .watchProgress(boardId, resetDaily: resetDaily);
});

final picturesProvider = StreamProvider.family<List<PictureRow>, PictureSource>(
  (ref, source) => ref.watch(repositoryProvider).watchPictures(source),
);

/// Bytes of a stored picture. Kept alive so the decoded image stays cached.
final pictureBytesProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  id,
) async {
  final row = await ref.watch(repositoryProvider).getPicture(id);
  return row?.bytes;
});

final speakerProvider = Provider<Speaker>((ref) {
  final speaker = Speaker();
  ref.listen(currentSettingsProvider, (_, s) {
    speaker
      ..enabled = s.speechEnabled
      ..rate = s.speechRate;
  }, fireImmediately: true);
  ref.onDispose(speaker.stop);
  return speaker;
});

final arasaacClientProvider = Provider<ArasaacClient>((ref) {
  final client = ArasaacClient();
  ref.onDispose(client.close);
  return client;
});

final transferProvider = Provider<BoardTransfer>((ref) {
  final catalog = ref.watch(symbolCatalogProvider);
  return BoardTransfer(
    ref.watch(repositoryProvider),
    symbolExists: catalog.symbols.isEmpty ? null : catalog.contains,
  );
});
