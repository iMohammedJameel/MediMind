import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

/// Manages the looping alarm sound + vibration for medication dose reminders.
///
/// Uses the **alarm** audio session so it plays even when the device is in
/// silent mode — exactly like a native alarm clock.
///
/// The alarm auto-stops after [maxDuration] to prevent infinite drain if the
/// user never interacts (dose is then treated as missed by the backend sweep).
class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  AudioPlayer? _player;
  Timer? _vibrationTimer;
  Timer? _autoStopTimer;

  /// Whether the alarm is currently ringing.
  bool get isRinging => _player?.playing ?? false;

  /// Maximum alarm ring time before auto-stop (battery safety net).
  static const Duration maxDuration = Duration(minutes: 5);

  /// Vibration pattern: vibrate 500ms, pause 1000ms — repeating.
  static const int _vibMs = 500;
  static const int _pauseMs = 1000;

  /// Start the looping alarm sound + vibration.
  ///
  /// Safe to call multiple times — only one alarm runs at a time.
  Future<void> startAlarm() async {
    // Don't double-start (also covers a half-initialized player from a
    // previous failed attempt — see the catch below).
    if (isRinging || _player != null) return;

    try {
      // Configure audio session for alarm mode — plays over silent/DND.
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.alarm,
          flags: AndroidAudioFlags.audibilityEnforced,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));

      // --- Audio ---
      _player = AudioPlayer();
      await _player!.setAsset('assets/sounds/alarm_tone.wav');
      await _player!.setLoopMode(LoopMode.one);
      await _player!.setVolume(1.0);
      await _player!.play();
    } catch (e) {
      // If audio fails (missing asset, etc.), continue with vibration only.
      // Dispose the half-initialized player so the next startAlarm() gets a
      // clean slate instead of leaking it.
      debugPrint('[AlarmService] alarm audio error: $e');
      try {
        await _player?.dispose();
      } catch (_) {/* already disposed */}
      _player = null;
    }

    // --- Vibration (periodic) ---
    _startVibrationLoop();

    // --- Auto-stop safety net ---
    _autoStopTimer = Timer(maxDuration, () {
      stopAlarm();
    });
  }

  /// Stop the alarm sound + vibration immediately.
  Future<void> stopAlarm() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    try {
      if (_player != null) {
        await _player!.stop();
        await _player!.dispose();
        _player = null;
      }
    } catch (_) {
      // Player already disposed — ignore.
      _player = null;
    }
  }

  void _startVibrationLoop() {
    // Immediate first vibration
    HapticFeedback.heavyImpact();

    _vibrationTimer = Timer.periodic(
      const Duration(milliseconds: _vibMs + _pauseMs),
      (_) {
        HapticFeedback.heavyImpact();
      },
    );
  }
}
