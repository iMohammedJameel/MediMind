import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/models/dose_event_model.dart';
import 'package:medimind/shared/network/local/cache_helper.dart';
import 'package:medimind/shared/utils/formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';

DoseEventModel _doseAt(DateTime t, String status) => DoseEventModel(
      id: 'd${t.millisecondsSinceEpoch}-$status',
      medicationId: 'm1',
      medicationName: 'X',
      scheduledFor: t,
      status: status,
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
  });

  group('AppFormatters — Egyptian elderly formatting', () {
    test('12-hour Arabic with ص/م and Arabic-Indic digits (default)', () {
      final t = DateTime(2026, 1, 15, 20, 30); // 8:30 PM
      expect(AppFormatters.timeOfDay(t, locale: 'ar'), '٨:٣٠ م');
      final morning = DateTime(2026, 1, 15, 5, 5); // 5:05 AM
      expect(AppFormatters.timeOfDay(morning, locale: 'ar'), '٥:٠٥ ص');
    });

    test('noon and midnight map to ١٢', () {
      expect(AppFormatters.timeOfDay(DateTime(2026, 1, 15, 0, 0)), '١٢:٠٠ ص');
      expect(AppFormatters.timeOfDay(DateTime(2026, 1, 15, 12, 0)), '١٢:٠٠ م');
    });

    test('24-hour switch respects the setting', () async {
      await CacheHelper.setUse24Hour(true);
      expect(
        AppFormatters.timeOfDay(DateTime(2026, 1, 15, 20, 30)),
        '٢٠:٣٠',
      );
    });

    test('Latin digits switch respects the setting', () async {
      await CacheHelper.setArabicDigits(false);
      expect(
        AppFormatters.timeOfDay(DateTime(2026, 1, 15, 20, 30), locale: 'ar'),
        '8:30 م',
      );
    });

    test('English 12-hour', () {
      expect(
        AppFormatters.timeOfDay(DateTime(2026, 1, 15, 20, 30),
            locale: 'en', arabicIndic: false),
        '8:30 PM',
      );
    });

    test('date with Arabic month name', () {
      expect(
        AppFormatters.date(DateTime(2026, 1, 15), locale: 'ar'),
        '١٥ يناير ٢٠٢٦',
      );
      expect(
        AppFormatters.date(DateTime(2026, 11, 2), locale: 'en',
            arabicIndic: false),
        '2 November 2026',
      );
    });

    test('notification timestamp combines date + time', () {
      final out = AppFormatters.dateTime(DateTime(2026, 1, 15, 9, 30));
      expect(out, '١٥ يناير، ٩:٣٠ ص');
    });

    test('DoseEventModel.timeLabel honors preferences', () async {
      final dose = _doseAt(DateTime(2026, 1, 15, 20, 30), 'PENDING');
      expect(dose.timeLabel, '٨:٣٠ م');
      await CacheHelper.setUse24Hour(true);
      expect(dose.timeLabel, '٢٠:٣٠');
    });
  });

  group('AdherenceSummary.adherenceStreak — reward system', () {
    final now = DateTime(2026, 1, 15, 20, 0);

    test('3 consecutive complete days -> streak 3', () {
      final doses = [
        // Today: both doses due & taken.
        _doseAt(DateTime(2026, 1, 15, 8), 'TAKEN'),
        _doseAt(DateTime(2026, 1, 15, 18), 'TAKEN'),
        // Yesterday.
        _doseAt(DateTime(2026, 1, 14, 8), 'TAKEN'),
        _doseAt(DateTime(2026, 1, 14, 18), 'TAKEN'),
        // Day before.
        _doseAt(DateTime(2026, 1, 13, 8), 'TAKEN'),
        _doseAt(DateTime(2026, 1, 13, 18), 'TAKEN'),
      ];
      expect(AdherenceSummary.adherenceStreak(doses, now), 3);
    });

    test('a missed dose yesterday breaks the chain at 1', () {
      final doses = [
        _doseAt(DateTime(2026, 1, 15, 8), 'TAKEN'),
        _doseAt(DateTime(2026, 1, 14, 8), 'TAKEN'),
        _doseAt(DateTime(2026, 1, 14, 18), 'MISSED'),
      ];
      expect(AdherenceSummary.adherenceStreak(doses, now), 1);
    });

    test('skipped dose also breaks the chain', () {
      final doses = [
        _doseAt(DateTime(2026, 1, 15, 8), 'TAKEN'),
        _doseAt(DateTime(2026, 1, 14, 8), 'SKIPPED'),
      ];
      expect(AdherenceSummary.adherenceStreak(doses, now), 1);
    });

    test('today incomplete (evening dose still pending) keeps yesterday streak', () {
      final doses = [
        _doseAt(DateTime(2026, 1, 15, 8), 'TAKEN'),
        _doseAt(DateTime(2026, 1, 15, 22), 'PENDING'), // not due yet
        _doseAt(DateTime(2026, 1, 14, 8), 'TAKEN'),
        _doseAt(DateTime(2026, 1, 14, 18), 'TAKEN'),
      ];
      // Today counts as complete for doses due so far (morning taken), and
      // yesterday was complete → streak 2.
      expect(AdherenceSummary.adherenceStreak(doses, now), 2);
    });

    test('empty data -> streak 0 and no milestone', () {
      expect(AdherenceSummary.adherenceStreak(const [], now), 0);
      expect(AdherenceSummary.streakMilestone(0), isNull);
      expect(AdherenceSummary.streakMilestone(2), isNull);
    });

    test('milestones map 3/7/14/30', () {
      expect(AdherenceSummary.streakMilestone(3)!.$1, 3);
      expect(AdherenceSummary.streakMilestone(6)!.$1, 3);
      expect(AdherenceSummary.streakMilestone(7)!.$1, 7);
      expect(AdherenceSummary.streakMilestone(13)!.$1, 7);
      expect(AdherenceSummary.streakMilestone(14)!.$1, 14);
      expect(AdherenceSummary.streakMilestone(29)!.$1, 14);
      expect(AdherenceSummary.streakMilestone(30)!.$1, 30);
      expect(AdherenceSummary.streakMilestone(99)!.$1, 30);
    });

    test('no dose records for a day → chain stops there', () {
      final doses = [
        _doseAt(DateTime(2026, 1, 15, 8), 'TAKEN'),
        _doseAt(DateTime(2026, 1, 13, 8), 'TAKEN'), // gap on the 14th
      ];
      expect(AdherenceSummary.adherenceStreak(doses, now), 1);
    });
  });
}
