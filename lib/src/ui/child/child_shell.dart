import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../theme.dart';
import 'adult_gate.dart';

/// An action offered to the adult after unlocking the child view.
class ChildMenuAction {
  const ChildMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
}

/// The frame around every child screen: full screen, screen kept awake, no
/// back button, and only a quiet lock in the corner for adults.
class ChildShell extends StatefulWidget {
  const ChildShell({
    super.key,
    required this.child,
    this.actions = const [],
    this.header,
  });

  final Widget child;

  /// Extra actions shown after the adult check (besides "Leave child view").
  final List<ChildMenuAction> actions;

  /// Optional content shown left of the lock (e.g. the progress rail).
  final Widget? header;

  @override
  State<ChildShell> createState() => _ChildShellState();
}

class _ChildShellState extends State<ChildShell> {
  @override
  void initState() {
    super.initState();
    unawaited(_enter());
  }

  Future<void> _enter() async {
    try {
      if (!kIsWeb) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
      await WakelockPlus.enable();
    } catch (_) {
      // Not supported on this platform; the child view still works.
    }
  }

  Future<void> _leave() async {
    try {
      if (!kIsWeb) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      await WakelockPlus.disable();
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_leave());
    super.dispose();
  }

  Future<void> _openMenu() async {
    final navigator = Navigator.of(context);
    final action = await showModalBottomSheet<VoidCallback>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final a in widget.actions)
                ListTile(
                  leading: Icon(a.icon),
                  title: Text(a.label),
                  onTap: () => Navigator.of(context).pop(a.onSelected),
                ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Leave child view'),
                onTap: () => Navigator.of(context).pop(() {
                  if (navigator.canPop()) {
                    navigator.pop();
                  } else {
                    navigator.pushReplacementNamed('/home');
                  }
                }),
              ),
            ],
          ),
        ),
      ),
    );
    action?.call();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // The system back gesture never leaves the child view.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: KidColors.background,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: widget.header ?? const SizedBox(height: 56),
                      ),
                      GateButton(onUnlocked: _openMenu),
                    ],
                  ),
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
