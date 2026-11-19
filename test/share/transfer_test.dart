import 'dart:typed_data';

import 'package:daysteps/src/data/models.dart';
import 'package:daysteps/src/share/board_codec.dart';
import 'package:daysteps/src/share/transfer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('a board with a photo moves to another device intact', () async {
    final phone = memoryRepository();
    final tablet = memoryRepository();
    addTearDown(phone.db.close);
    addTearDown(tablet.db.close);

    final photo = Uint8List.fromList([9, 8, 7, 6]);
    final pictureId = await phone.addPicture(
      source: PictureSource.photo,
      label: 'Our car',
      bytes: photo,
      mimeType: 'image/jpeg',
    );
    final boardId = await phone.createBoard(
      title: 'Saturday',
      kind: BoardKind.schedule,
      steps: [
        const StepDraft(
          label: 'Breakfast',
          picture: SymbolPicture('mulberry/breakfast'),
        ),
        StepDraft(label: 'Car', picture: StoredPicture(pictureId)),
        const StepDraft(
          label: 'Retired symbol',
          picture: SymbolPicture('gone/symbol'),
        ),
      ],
    );

    // Phone: export to a file.
    final bytes = BoardCodec.encodeFile(
      await BoardTransfer(phone).export([boardId]),
    );

    // Tablet: import it.
    final ids = await BoardTransfer(
      tablet,
      symbolExists: (id) => id != 'gone/symbol',
    ).import(BoardCodec.decodeFile(bytes));

    final board = (await tablet.getBoard(ids.single))!;
    expect(board.title, 'Saturday');
    expect(board.steps[0].picture, const SymbolPicture('mulberry/breakfast'));
    final car = board.steps[1].picture! as StoredPicture;
    expect(car.pictureId, isNot(pictureId), reason: 'stored under a fresh id');
    expect((await tablet.getPicture(car.pictureId))!.bytes, photo);
    expect(
      board.steps[2].picture,
      isNull,
      reason: 'unknown symbols fall back to words',
    );
  });

  test('importing keeps board order and pads first–then boards', () async {
    final repo = memoryRepository();
    addTearDown(repo.db.close);
    final ids = await BoardTransfer(repo).import(
      const SharedPackage(
        boards: [
          SharedBoard(title: 'One', kind: BoardKind.schedule, steps: []),
          SharedBoard(
            title: 'Two',
            kind: BoardKind.firstThen,
            steps: [SharedStep(label: 'Only')],
          ),
        ],
      ),
    );
    final boards = await repo.getBoards();
    expect([for (final b in boards) b.title], ['One', 'Two']);
    expect((await repo.getBoard(ids[1]))!.steps.length, 2);
  });
}
