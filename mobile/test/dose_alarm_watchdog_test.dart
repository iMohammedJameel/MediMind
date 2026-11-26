import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/models/dose_event_model.dart';
import 'package:medimind/services/dose_alarm_watchdog.dart';

DoseEventModel _dose(
  String id,
  DateTime at, {
  String status = 'PENDING',
  String name = 'Amaryl',
}) =>
    DoseEventModel(
      id: id,
      medicationId: 'med-$id',
      medicationName: name,
      scheduledFor: at,
      status: status,
    );

void main() {
  group('DoseAlarmWatchdog', () {
    test('arms only future pending/late doses within 24h and fires on time',
        () async {
      var now = DateTime(2026, 11, 26, 10, 0, 0);
      final fired = <String>[];
      final watchdog = DoseAlarmWatchdog(now: () => now)
        ..canTrigger = (() => true)
        ..onDoseDue = (d) {
          fired.add(d.id);
        };

      watchdog.arm([
        _dose('past', now.subtract(const Duration(minutes: 5))),
        _dose('taken', now.add(const Duration(milliseconds: 20)),
            status: 'TAKEN'),
        _dose('skipped', now.add(const Duration(milliseconds: 20)),
            status: 'SKIPPED'),
        _dose('due_soon', now.add(const Duration(milliseconds: 60))),
        _dose('later', now.add(const Duration(hours: 2))),
        _dose('too_far', now.add(const Duration(hours: 30))),
      ]);

      expect(watchdog.armedCount, 2);
      await Future<void>.delayed(const Duration(milliseconds: 110));
      expect(fired, ['due_soon']);
      expect(watchdog.armedCount, 1);

      watchdog.clear();
    });

    test('armSnooze schedules future snooze and suppresses duplicate signature',
        () async {
      final now = DateTime(2026, 11, 26, 10, 0, 0);
      final fired = <String>[];
      final watchdog = DoseAlarmWatchdog(now: () => now)
        ..onDoseDue = (d) {
          fired.add(d.id);
        };

      final dose = _dose('d1', now.add(const Duration(minutes: 10)));
      watchdog.armSnooze(dose, now.add(const Duration(milliseconds: 50)));
      expect(watchdog.armedCount, 1);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(fired, ['d1']);
      expect(watchdog.armedCount, 0);

      // Re-arming same dose & same minute doesn't re-fire twice.
      watchdog.armSnooze(dose, now.add(const Duration(milliseconds: 50)));
      watchdog.arm([_dose('d1', now.add(const Duration(milliseconds: 50)))]);
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(fired, ['d1', 'd1']); // armSnooze explicitly cleared signature; arm respects it.

      watchdog.clear();
    });

    test('cancelDose and canTrigger prevent unwanted firing', () async {
      final now = DateTime(2026, 11, 26, 10, 0, 0);
      final fired = <String>[];
      var allowed = false;
      final watchdog = DoseAlarmWatchdog(now: () => now)
        ..canTrigger = (() => allowed)
        ..onDoseDue = (d) {
          fired.add(d.id);
        };

      watchdog.arm([
        _dose('c1', now.add(const Duration(milliseconds: 40))),
        _dose('c2', now.add(const Duration(milliseconds: 70))),
      ]);
      watchdog.cancelDose('c1');
      expect(watchdog.armedCount, 1);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      // Gate returned false -> c2 did not trigger.
      expect(fired, isEmpty);

      allowed = true;
      watchdog.arm([_dose('c3', now.add(const Duration(milliseconds: 40)))]);
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(fired, ['c3']);

      watchdog.clear();
    });

    test('checkDueOnResume triggers within grace window only', () async {
      var now = DateTime(2026, 11, 26, 10, 0, 0);
      final fired = <String>[];
      final watchdog = DoseAlarmWatchdog(now: () => now)
        ..onDoseDue = (d) {
          fired.add(d.id);
        };

      watchdog.arm([
        _dose('recent', now.add(const Duration(seconds: 30))),
      ]);
      expect(watchdog.armedCount, 1);

      // Simulate OS pausing app for 45 seconds (15s past due -> within 90s grace).
      now = now.add(const Duration(seconds: 45));
      await watchdog.checkDueOnResume();
      expect(fired, ['recent']);

      // Simulate stale dose missed by >90s.
      watchdog.arm([
        _dose('stale', now.add(const Duration(seconds: 10))),
      ]);
      now = now.add(const Duration(minutes: 5));
      await watchdog.checkDueOnResume();
      expect(fired, ['recent']);

      watchdog.clear();
    });
  });
}
