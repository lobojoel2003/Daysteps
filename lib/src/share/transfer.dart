import '../data/models.dart';
import '../data/repository.dart';
import 'board_codec.dart';

/// Moves boards between the local database and share packages.
class BoardTransfer {
  BoardTransfer(this.repository, {this.symbolExists});

  final DaystepsRepository repository;

  /// Used to drop references to pictograms this version doesn't bundle.
  final bool Function(String symbolId)? symbolExists;

  /// Builds a package with the given boards and every photo they use.
  Future<SharedPackage> export(List<String> boardIds) async {
    final boards = <SharedBoard>[];
    final pictures = <String, SharedPicture>{};
    for (final id in boardIds) {
      final board = await repository.getBoard(id);
      if (board == null) continue;
      boards.add(toShared(board));
      for (final step in board.steps) {
        final ref = step.picture;
        if (ref is StoredPicture && !pictures.containsKey(ref.pictureId)) {
          final row = await repository.getPicture(ref.pictureId);
          if (row != null) {
            pictures[ref.pictureId] = SharedPicture(
              label: row.label,
              mimeType: row.mimeType,
              bytes: row.bytes,
              source: row.source,
              attribution: row.attribution,
              remoteId: row.remoteId,
            );
          }
        }
      }
    }
    return SharedPackage(boards: boards, pictures: pictures);
  }

  static SharedBoard toShared(Board board) => SharedBoard(
    title: board.title,
    kind: board.kind,
    steps: [
      for (final s in board.steps)
        SharedStep(
          label: s.label,
          picture: s.picture?.encoded,
          duration: s.duration,
        ),
    ],
  );

  /// Adds every board in [package] as a new board. Returns the new ids.
  Future<List<String>> import(SharedPackage package) async {
    // Store the pictures first, under fresh ids.
    final pictureIds = <String, String>{};
    for (final entry in package.pictures.entries) {
      final p = entry.value;
      if (p.remoteId != null) {
        final existing = await repository.findByRemoteId(p.source, p.remoteId!);
        if (existing != null) {
          pictureIds[entry.key] = existing.id;
          continue;
        }
      }
      pictureIds[entry.key] = await repository.addPicture(
        source: p.source,
        label: p.label,
        bytes: p.bytes,
        mimeType: p.mimeType,
        attribution: p.attribution,
        remoteId: p.remoteId,
      );
    }

    final ids = <String>[];
    for (final board in package.boards.reversed) {
      final steps = [for (final s in board.steps) _draft(s, pictureIds)];
      if (board.kind == BoardKind.firstThen) {
        while (steps.length < 2) {
          steps.add(const StepDraft(label: ''));
        }
      }
      ids.add(
        await repository.createBoard(
          title: board.title,
          kind: board.kind,
          steps: board.kind == BoardKind.firstThen
              ? steps.take(2).toList()
              : steps,
        ),
      );
    }
    return ids.reversed.toList();
  }

  StepDraft _draft(SharedStep s, Map<String, String> pictureIds) {
    PictureRef? picture;
    switch (PictureRef.tryParse(s.picture)) {
      case SymbolPicture(:final symbolId):
        if (symbolExists?.call(symbolId) ?? true) {
          picture = SymbolPicture(symbolId);
        }
      case StoredPicture(:final pictureId):
        final mapped = pictureIds[pictureId];
        if (mapped != null) picture = StoredPicture(mapped);
      case null:
        break;
    }
    return StepDraft(label: s.label, picture: picture, duration: s.duration);
  }
}
