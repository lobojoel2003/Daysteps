import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads card names aloud with the platform's own text-to-speech engine
/// (Android TextToSpeech, or the browser's Web Speech API). Works offline when
/// the device has an offline voice installed.
class Speaker {
  Speaker({this._tts});

  FlutterTts? _tts;
  bool _ready = false;
  bool enabled = true;
  double _rate = 0.45;

  /// Speech rate from 0.1 (slow) to 1.0 (fast); 0.5 is the platform's normal
  /// speed.
  set rate(double value) {
    final r = value.clamp(0.1, 1.0);
    if (r == _rate) return;
    _rate = r;
    if (_ready) unawaited(_applyRate());
  }

  double get rate => _rate;

  Future<void> _ensureReady() async {
    if (_ready) return;
    try {
      final tts = _tts ??= FlutterTts();
      await tts.awaitSpeakCompletion(false);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      _ready = true;
      await _applyRate();
    } catch (e) {
      debugPrint('Text-to-speech unavailable: $e');
    }
  }

  Future<void> _applyRate() async {
    // Android maps Flutter's 0.5 to its normal speed; the Web Speech API's
    // normal speed is 1.0. Scale so the setting means the same everywhere.
    final platformRate = kIsWeb ? _rate * 2 : _rate;
    try {
      await _tts?.setSpeechRate(platformRate);
    } catch (_) {}
  }

  /// Speaks [text], interrupting anything already being said.
  Future<void> say(String text) async {
    final t = text.trim();
    if (!enabled || t.isEmpty) return;
    await _ensureReady();
    if (!_ready) return;
    try {
      await _tts!.stop();
      await _tts!.speak(t);
    } catch (e) {
      debugPrint('Text-to-speech failed: $e');
    }
  }

  /// Speaks even when speech is turned off in settings (for "test voice").
  Future<void> preview(String text) async {
    final wasEnabled = enabled;
    enabled = true;
    try {
      await say(text);
    } finally {
      enabled = wasEnabled;
    }
  }

  Future<void> stop() async {
    if (!_ready) return;
    try {
      await _tts!.stop();
    } catch (_) {}
  }
}
