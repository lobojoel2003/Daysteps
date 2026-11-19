import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// What kind of board this is.
enum BoardKind {
  /// An ordered list of steps: "what is happening now, what comes next".
  schedule,

  /// Exactly two cards: "first this, then that".
  firstThen,
}

/// Where a stored (non-bundled) picture came from.
enum PictureSource { photo, arasaac }

/// A reference to the picture shown on a card.
///
/// Serialised as `sym:<symbol id>` for bundled pictograms and `img:<uuid>` for
/// pictures stored in the database (photos, ARASAAC downloads).
@immutable
sealed class PictureRef {
  const PictureRef();

  static const _symbolPrefix = 'sym:';
  static const _imagePrefix = 'img:';

  /// Parses the stored form. Returns null for null, empty or unknown values.
  static PictureRef? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.startsWith(_symbolPrefix) &&
        value.length > _symbolPrefix.length) {
      return SymbolPicture(value.substring(_symbolPrefix.length));
    }
    if (value.startsWith(_imagePrefix) && value.length > _imagePrefix.length) {
      return StoredPicture(value.substring(_imagePrefix.length));
    }
    return null;
  }

  /// The stored string form.
  String get encoded;

  @override
  String toString() => encoded;
}

/// A pictogram bundled with the app (Mulberry Symbols or OpenMoji).
final class SymbolPicture extends PictureRef {
  const SymbolPicture(this.symbolId);
  final String symbolId;

  @override
  String get encoded => '${PictureRef._symbolPrefix}$symbolId';

  @override
  bool operator ==(Object other) =>
      other is SymbolPicture && other.symbolId == symbolId;

  @override
  int get hashCode => Object.hash('sym', symbolId);
}

/// A photo or downloaded pictogram stored in the local database.
final class StoredPicture extends PictureRef {
  const StoredPicture(this.pictureId);
  final String pictureId;

  @override
  String get encoded => '${PictureRef._imagePrefix}$pictureId';

  @override
  bool operator ==(Object other) =>
      other is StoredPicture && other.pictureId == pictureId;

  @override
  int get hashCode => Object.hash('img', pictureId);
}

/// One card on a board, as the UI sees it.
@immutable
class BoardStep {
  const BoardStep({
    required this.id,
    required this.label,
    this.picture,
    this.duration,
  });

  final String id;
  final String label;
  final PictureRef? picture;

  /// Optional visual-timer length.
  final Duration? duration;

  BoardStep copyWith({
    String? label,
    PictureRef? picture,
    bool clearPicture = false,
    Duration? duration,
    bool clearDuration = false,
  }) => BoardStep(
    id: id,
    label: label ?? this.label,
    picture: clearPicture ? null : (picture ?? this.picture),
    duration: clearDuration ? null : (duration ?? this.duration),
  );

  @override
  bool operator ==(Object other) =>
      other is BoardStep &&
      other.id == id &&
      other.label == label &&
      other.picture == picture &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(id, label, picture, duration);
}

/// A board with its steps in order.
@immutable
class Board {
  const Board({
    required this.id,
    required this.title,
    required this.kind,
    required this.steps,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final BoardKind kind;
  final List<BoardStep> steps;
  final DateTime updatedAt;

  bool get isEmpty => steps.isEmpty;

  /// First–then boards always show exactly two slots.
  BoardStep? get first => steps.firstOrNull;
  BoardStep? get then => steps.length > 1 ? steps[1] : null;

  /// Whether the board has enough content to show to a child.
  bool get isPlayable => switch (kind) {
    BoardKind.schedule => steps.isNotEmpty,
    BoardKind.firstThen => steps.length >= 2,
  };

  @override
  bool operator ==(Object other) =>
      other is Board &&
      other.id == id &&
      other.title == title &&
      other.kind == kind &&
      other.updatedAt == updatedAt &&
      const ListEquality<BoardStep>().equals(other.steps, steps);

  @override
  int get hashCode =>
      Object.hash(id, title, kind, updatedAt, Object.hashAll(steps));
}

/// The data needed to create a new step.
@immutable
class StepDraft {
  const StepDraft({required this.label, this.picture, this.duration});

  final String label;
  final PictureRef? picture;
  final Duration? duration;
}

/// How the visual timer shows time passing.
enum TimerStyle {
  /// A coloured disc that is eaten away like a clock hand sweeping round.
  pie,

  /// A coloured disc whose size shrinks towards the centre.
  shrink,
}

/// Colours offered for the visual timer disc. Calm, high-contrast hues.
const timerColorChoices = <int>[
  0xFFE4572E, // tomato
  0xFF2A9D8F, // teal
  0xFF3A86FF, // blue
  0xFF8E5CF7, // violet
  0xFFF4A259, // orange
  0xFF43AA8B, // green
];

/// User preferences. Stored as key/value strings in the settings table.
@immutable
class AppSettings {
  const AppSettings({
    this.speechEnabled = true,
    this.speechRate = 0.45,
    this.showLabels = true,
    this.calmMotion = false,
    this.timerColor = 0xFFE4572E,
    this.timerStyle = TimerStyle.pie,
    this.showTimeLeft = false,
    this.openInChildMode = false,
    this.resetDaily = true,
    this.activeBoardId,
    this.seeded = false,
  });

  /// Read card names aloud with the device's text-to-speech engine.
  final bool speechEnabled;

  /// Speech rate, 0.1 (slow) to 1.0 (fast). 0.45 is a calm default.
  final double speechRate;

  /// Show words under the pictures in the child view.
  final bool showLabels;

  /// Replace bouncy animations with simple fades.
  final bool calmMotion;

  /// ARGB colour of the visual timer disc.
  final int timerColor;

  /// Pie (Time-Timer style) or a shrinking disc.
  final TimerStyle timerStyle;

  /// Show minutes left as digits on the timer (off by default: the shrinking
  /// disc is the point).
  final bool showTimeLeft;

  /// Open straight to the child view on launch, so a child's device "just
  /// shows it".
  final bool openInChildMode;

  /// Start boards from the first step again each new day.
  final bool resetDaily;

  /// The board shown in the child view.
  final String? activeBoardId;

  /// Whether the example boards have been created.
  final bool seeded;

  AppSettings copyWith({
    bool? speechEnabled,
    double? speechRate,
    bool? showLabels,
    bool? calmMotion,
    int? timerColor,
    TimerStyle? timerStyle,
    bool? showTimeLeft,
    bool? openInChildMode,
    bool? resetDaily,
    String? activeBoardId,
    bool clearActiveBoard = false,
    bool? seeded,
  }) => AppSettings(
    speechEnabled: speechEnabled ?? this.speechEnabled,
    speechRate: speechRate ?? this.speechRate,
    showLabels: showLabels ?? this.showLabels,
    calmMotion: calmMotion ?? this.calmMotion,
    timerColor: timerColor ?? this.timerColor,
    timerStyle: timerStyle ?? this.timerStyle,
    showTimeLeft: showTimeLeft ?? this.showTimeLeft,
    openInChildMode: openInChildMode ?? this.openInChildMode,
    resetDaily: resetDaily ?? this.resetDaily,
    activeBoardId: clearActiveBoard
        ? null
        : (activeBoardId ?? this.activeBoardId),
    seeded: seeded ?? this.seeded,
  );

  Map<String, String> toMap() => {
    'speechEnabled': '$speechEnabled',
    'speechRate': '$speechRate',
    'showLabels': '$showLabels',
    'calmMotion': '$calmMotion',
    'timerColor': '$timerColor',
    'timerStyle': timerStyle.name,
    'showTimeLeft': '$showTimeLeft',
    'openInChildMode': '$openInChildMode',
    'resetDaily': '$resetDaily',
    'activeBoardId': activeBoardId ?? '',
    'seeded': '$seeded',
  };

  factory AppSettings.fromMap(Map<String, String> map) {
    const d = AppSettings();
    bool b(String key, bool fallback) => switch (map[key]) {
      'true' => true,
      'false' => false,
      _ => fallback,
    };
    final rate = double.tryParse(map['speechRate'] ?? '');
    final color = int.tryParse(map['timerColor'] ?? '');
    final active = map['activeBoardId'];
    return AppSettings(
      speechEnabled: b('speechEnabled', d.speechEnabled),
      speechRate: (rate ?? d.speechRate).clamp(0.1, 1.0),
      showLabels: b('showLabels', d.showLabels),
      calmMotion: b('calmMotion', d.calmMotion),
      timerColor: color ?? d.timerColor,
      timerStyle:
          TimerStyle.values.asNameMap()[map['timerStyle']] ?? d.timerStyle,
      showTimeLeft: b('showTimeLeft', d.showTimeLeft),
      openInChildMode: b('openInChildMode', d.openInChildMode),
      resetDaily: b('resetDaily', d.resetDaily),
      activeBoardId: (active == null || active.isEmpty) ? null : active,
      seeded: b('seeded', d.seeded),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      const MapEquality<String, String>().equals(other.toMap(), toMap());

  @override
  int get hashCode => Object.hashAll(toMap().values);
}
