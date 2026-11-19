import 'package:material_ui/material_ui.dart';

/// Brand colours. Calm, warm and high-contrast; no saturated neon.
abstract final class Brand {
  static const teal = Color(0xFF1D6F7A);
  static const tealDark = Color(0xFF12474F);
  static const sunflower = Color(0xFFF6B93B);
  static const coral = Color(0xFFEF7B5B);
  static const leaf = Color(0xFF3BAA7E);
  static const cream = Color(0xFFFFF8EE);
  static const sand = Color(0xFFFFF4E0);
  static const ink = Color(0xFF21323A);
  static const fontFamily = 'Atkinson Hyperlegible';
}

/// Colours used only in the child's view.
abstract final class KidColors {
  static const background = Brand.cream;
  static const card = Colors.white;
  static const now = Brand.sunflower;
  static const done = Brand.leaf;
  static const text = Brand.ink;
  static const muted = Color(0xFF8A9AA1);
  static const track = Color(0xFFEDE6DA);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.teal,
    brightness: brightness,
    primary: brightness == Brightness.light ? Brand.teal : null,
    secondary: brightness == Brightness.light ? Brand.coral : null,
    tertiary: Brand.sunflower,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: Brand.fontFamily,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFFBF8F3)
        : scheme.surface,
    visualDensity: VisualDensity.standard,
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: base.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: Brand.fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: brightness == Brightness.light
          ? Colors.white
          : scheme.surfaceContainer,
      shape: rounded.copyWith(
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: Brand.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: Brand.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      extendedTextStyle: const TextStyle(
        fontFamily: Brand.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.light
          ? Colors.white
          : scheme.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(fontFamily: Brand.fontFamily, fontSize: 14),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}

/// Whether the child view should avoid bouncy motion.
bool calmMotionOf(BuildContext context, {required bool setting}) =>
    setting || MediaQuery.disableAnimationsOf(context);
