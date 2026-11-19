import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'src/app.dart';
import 'src/data/database.dart';
import 'src/data/repository.dart';
import 'src/data/seed.dart';
import 'src/share/board_codec.dart';
import 'src/state/providers.dart';
import 'src/symbols/symbol_catalog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerLicenses();

  final repository = DaystepsRepository(AppDatabase.open());
  final catalog = await SymbolCatalog.load();

  var settings = await repository.getSettings();
  if (!settings.seeded) {
    final first = await seedExampleBoards(
      repository,
      symbolExists: catalog.contains,
    );
    settings = settings.copyWith(seeded: true, activeBoardId: first);
    await repository.saveSettings(settings);
  }

  // A board shared as a link: https://…/Daysteps/#import=DS1.…
  String? importLink;
  if (kIsWeb && BoardCodec.looksLikeQr(Uri.base.fragment)) {
    importLink = Uri.base.toString();
    // Tidy the address bar so a reload doesn't import twice.
    unawaited(
      SystemNavigator.routeInformationUpdated(
        uri: Uri(path: '/'),
        replace: true,
      ),
    );
  }

  final activeBoard = settings.activeBoardId;
  final openChild =
      settings.openInChildMode &&
      activeBoard != null &&
      (await repository.getBoard(activeBoard))?.isPlayable == true;

  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        symbolCatalogProvider.overrideWithValue(catalog),
      ],
      child: DaystepsApp(
        childBoardId: openChild ? activeBoard : null,
        importLink: importLink,
      ),
    ),
  );
}

void _registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['Mulberry Symbols'],
      'Mulberry Symbols by Steve Lee are licenced under the Creative Commons '
      'Attribution-ShareAlike 4.0 License. See https://mulberrysymbols.org for details.\n\n'
      'The copies bundled with Daysteps were optimised and renamed (modified) and '
      'are shared under the same licence: https://creativecommons.org/licenses/by-sa/4.0/',
    );
    yield const LicenseEntryWithLineBreaks(
      ['OpenMoji'],
      'All emojis designed by OpenMoji – the open-source emoji and icon project. '
      'License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/).\n\n'
      'The copies bundled with Daysteps were optimised and renamed (modified) and '
      'are shared under the same licence.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['ARASAAC (optional downloads)'],
      'Pictogram author: Sergio Palao. Origin: ARASAAC (https://arasaac.org). '
      'License: CC BY-NC-SA 4.0 (https://creativecommons.org/licenses/by-nc-sa/4.0/). '
      'Owner: Government of Aragón (Spain).\n\n'
      'ARASAAC pictograms are not bundled with Daysteps. They are downloaded only '
      'when an adult chooses to, and may not be used commercially.',
    );
    final ofl = await rootBundle.loadString(
      'assets/fonts/AtkinsonHyperlegible-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['Atkinson Hyperlegible'], ofl);
  });
}
