import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'ui/adult/home_screen.dart';
import 'ui/adult/import_flow.dart';
import 'ui/child/child_mode_screen.dart';
import 'ui/theme.dart';

/// Route name of the adult home screen.
const homeRoute = '/home';

class DaystepsApp extends StatelessWidget {
  const DaystepsApp({super.key, this.childBoardId, this.importLink});

  /// When set, the app opens straight to this board's child view.
  final String? childBoardId;

  /// A shared-board link the app was opened with (web).
  final String? importLink;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daysteps',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // Ignore the browser's initial URL (it may hold a shared board).
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: homeRoute),
          builder: (_) => childBoardId != null && importLink == null
              ? ChildModeScreen(boardId: childBoardId!)
              : _Home(importLink: importLink),
        ),
      ],
      routes: {homeRoute: (_) => const _Home()},
    );
  }
}

/// The home screen, which also handles a shared link the app was opened with.
class _Home extends ConsumerStatefulWidget {
  const _Home({this.importLink});

  final String? importLink;

  @override
  ConsumerState<_Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<_Home> {
  @override
  void initState() {
    super.initState();
    final link = widget.importLink;
    if (link != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) importFromText(context, ref, link);
      });
    }
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
