import 'dart:async';

import '../models/dose_event_model.dart';

/// In-app foreground alarm timer for upcoming patient doses.
///
/// Why this exists: on Android, OS-scheduled local notifications fire in the
/// system tray, and Android suppresses `fullScreenIntent` whenever the screen is
/// unlocked or the app is already open in the foreground. Without an active
/// in-app timer, keeping MediMind open when a dose time arrives would show a
/// status-bar banner (or fall back to an inexact window if exact alarms are
/// disabled) without opening `AlarmScreen` or ringing `AlarmService`.
class DoseAlarmWatchdog {
  DoseAlarmWatchdog({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static final DoseAlarmWatchdog instance = DoseAlarmWatchdog();

  static const Duration resumeGraceWindow = Duration(seconds: 90);
  static const Duration _maxLookahead = Duration(hours: 24);

  final DateTime Function() _now;
  final Map<String, DateTime> _armedTargets = {};
  final Map<String, DoseEventModel> _armedDoses = {};
  final Set<String> _firedSignatures = {};

  Timer? _timer;
  String? _timerDoseId;

  /// Invoked when an armed dose reaches its scheduled (or snoozed) fire time.
  FutureOr<void> Function(DoseEventModel dose)? onDoseDue;

  /// Optional gate evaluated before firing (e.g., patient role + notifications ON).
  bool Function()? canTrigger;

  /// Replaces the armed schedule with active upcoming pending/late doses (and
  /// active snoozes). Past due doses are ignored here unless a snooze extends them.
  void arm(
    List<DoseEventModel> doses, {
    Map<String, DateTime> snoozes = const {},
  }) {
    final now = _now();
    _armedTargets.clear();
    _armedDoses.clear();

    for (final dose in doses) {
      if (!(dose.isPending || dose.isLate)) continue;
      final snoozeUntil = snoozes[dose.id];
      final target = (snoozeUntil != null && snoozeUntil.isAfter(now))
          ? snoozeUntil
          : dose.scheduledFor;
      if (!target.isAfter(now)) continue;
      if (target.difference(now) > _maxLookahead) continue;

      final sig = _signature(dose.id, target);
      if (_firedSignatures.contains(sig)) continue;

      _armedTargets[dose.id] = target;
      _armedDoses[dose.id] = dose;
    }

    _scheduleNextTimer();
  }

  /// Arms or updates a single snoozed dose reminder.
  void armSnooze(DoseEventModel dose, DateTime fireAt) {
    final now = _now();
    if (!fireAt.isAfter(now)) return;
    _armedTargets[dose.id] = fireAt;
    _armedDoses[dose.id] = dose;
    _firedSignatures.remove(_signature(dose.id, fireAt));
    _scheduleNextTimer();
  }

  /// Cancels any foreground timer for [doseId] (confirmed / skipped / deleted).
  void cancelDose(String doseId) {
    _armedTargets.remove(doseId);
    _armedDoses.remove(doseId);
    if (_timerDoseId == doseId) {
      _timer?.cancel();
      _timer = null;
      _timerDoseId = null;
      _scheduleNextTimer();
    }
  }

  /// Clears all armed timers (notifications disabled, logout, account deletion).
  void clear() {
    _timer?.cancel();
    _timer = null;
    _timerDoseId = null;
    _armedTargets.clear();
    _armedDoses.clear();
    _firedSignatures.clear();
  }

  /// Call on `AppLifecycleState.resumed` in case the Dart timer was paused by
  /// Android Doze right as a dose became due within [resumeGraceWindow].
  Future<void> checkDueOnResume() async {
    if (_armedTargets.isEmpty) return;
    final now = _now();
    String? dueId;
    DateTime? dueTarget;

    for (final entry in _armedTargets.entries) {
      final target = entry.value;
      if (!target.isAfter(now) &&
          now.difference(target) <= resumeGraceWindow) {
        if (dueTarget == null || target.isBefore(dueTarget)) {
          dueTarget = target;
          dueId = entry.key;
        }
      }
    }

    if (dueId != null && dueTarget != null) {
      await _triggerDose(dueId, dueTarget);
    }
    _scheduleNextTimer();
  }

  /// Visible for testing: number of currently armed future doses.
  int get armedCount => _armedTargets.length;

  /// Visible for testing: triggers any dose whose armed time has elapsed.
  Future<void> fireNextForTest() async {
    final next = _pickEarliestTarget();
    if (next == null) return;
    await _triggerDose(next.$1, next.$2);
    _scheduleNextTimer();
  }

  void _scheduleNextTimer() {
    _timer?.cancel();
    _timer = null;
    _timerDoseId = null;

    final next = _pickEarliestTarget();
    if (next == null) return;

    final now = _now();
    var delay = next.$2.difference(now);
    if (delay.isNegative) {
      delay = Duration.zero;
    }
    // Wait a tiny bit past the boundary only if zero to keep async ordering clean.
    _timerDoseId = next.$1;
    _timer = Timer(delay, () async {
      await _triggerDose(next.$1, next.$2);
      _scheduleNextTimer();
    });
  }

  (String, DateTime)? _pickEarliestTarget() {
    String? bestId;
    DateTime? bestAt;
    final now = _now();
    final staleIds = <String>[];

    for (final entry in _armedTargets.entries) {
      if (now.difference(entry.value) > resumeGraceWindow) {
        staleIds.add(entry.key);
        continue;
      }
      if (bestAt == null || entry.value.isBefore(bestAt)) {
        bestAt = entry.value;
        bestId = entry.key;
      }
    }

    for (final id in staleIds) {
      _armedTargets.remove(id);
      _armedDoses.remove(id);
    }

    if (bestId == null || bestAt == null) return null;
    return (bestId, bestAt);
  }

  Future<void> _triggerDose(String doseId, DateTime target) async {
    final dose = _armedDoses.remove(doseId);
    _armedTargets.remove(doseId);
    if (dose == null) return;

    final sig = _signature(doseId, target);
    if (_firedSignatures.contains(sig)) return;
    _firedSignatures.add(sig);

    if (canTrigger != null && !canTrigger!()) return;
    await onDoseDue?.call(dose);
  }

  static String _signature(String doseId, DateTime target) =>
      '$doseId@${target.millisecondsSinceEpoch ~/ 60000}';
}
