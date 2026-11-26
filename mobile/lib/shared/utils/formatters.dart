import '../network/local/cache_helper.dart';

/// Locale-aware time & number formatting for the Egyptian elderly market:
/// - 12-hour clock with ص/م (default) or 24-hour, per user setting.
/// - Arabic-Indic digits (١٢٣) optional, default on for Arabic UI.
/// - Manual Arabic month names — avoids `intl`'s initializeDateFormatting
///   which throws (crash) when the 'ar' date-symbol data isn't loaded.
class AppFormatters {
  AppFormatters._();

  static const _arDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  static const _arMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  static const _enMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _arWeekdays = [
    'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت',
  ];
  static const _enWeekdays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  /// Converts Latin digits to Arabic-Indic (٠١٢٣…) when [arabicIndic].
  static String digits(String input, {required bool arabicIndic}) {
    if (!arabicIndic) return input;
    return input.replaceAllMapped(
      RegExp(r'\d'),
      (m) => _arDigits[int.parse(m.group(0)!)],
    );
  }

  /// Formats digits honoring explicit [arabicIndic] or stored preference for
  /// [locale]; falls back cleanly when [CacheHelper] is uninitialized.
  static String digitsForLocale(
    String input, {
    String locale = 'ar',
    bool? arabicIndic,
  }) {
    try {
      return _digitsFor(input, locale, arabicIndic);
    } catch (_) {
      return digits(input, arabicIndic: arabicIndic ?? (locale == 'ar'));
    }
  }

  static String _digitsFor(String input, String locale, bool? arabicIndic) {
    final useArabic = arabicIndic ?? _defaultArabicDigits(locale);
    return digits(input, arabicIndic: useArabic);
  }

  static bool _defaultArabicDigits(String locale) {
    // Explicit stored preference always wins. Otherwise Arabic-Indic digits
    // are the default when FORMATTING Arabic (the [locale] the caller asked
    // for) — so an English-locale call renders Latin digits and an
    // Arabic-locale call renders ١٢٣, unless the user chose otherwise.
    //
    // NOTE: intentionally no try/catch — when preferences are unavailable
    // (CacheHelper not initialized, e.g. unit tests) the error propagates
    // so callers like DoseEventModel.timeLabel can fall back to plain HH:MM.
    final stored = CacheHelper.getArabicDigitsPref();
    if (stored != null) return stored;
    return locale == 'ar';
  }

  static bool _default24Hour(String locale) {
    // 12-hour ص/م is the norm in Egypt. No try/catch — see
    // [_defaultArabicDigits] for the error-propagation contract.
    return CacheHelper.getUse24Hour();
  }

  /// "٨:٣٠ م" / "8:30 PM" / "20:30" — reads the user's preferences.
  static String timeOfDay(
    DateTime t, {
    String locale = 'ar',
    bool? use24Hour,
    bool? arabicIndic,
  }) {
    final h24 = use24Hour ?? _default24Hour(locale);
    final isAr = locale == 'ar';
    if (h24) {
      final s =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      return _digitsFor(s, locale, arabicIndic);
    }
    final suffix = t.hour < 12 ? (isAr ? 'ص' : 'AM') : (isAr ? 'م' : 'PM');
    var h = t.hour % 12;
    if (h == 0) h = 12;
    return '${_digitsFor('$h', locale, arabicIndic)}:'
        '${_digitsFor(t.minute.toString().padLeft(2, '0'), locale, arabicIndic)} $suffix';
  }

  /// "١٥ يناير ٢٠٢٦" / "15 January 2026".
  static String date(
    DateTime t, {
    String locale = 'ar',
    bool? arabicIndic,
    bool withYear = true,
  }) {
    final isAr = locale == 'ar';
    final month = isAr ? _arMonths[t.month - 1] : _enMonths[t.month - 1];
    final day = _digitsFor('${t.day}', locale, arabicIndic);
    return withYear
        ? isAr
            ? '$day $month ${_digitsFor('${t.year}', locale, arabicIndic)}'
            : '$day $month ${t.year}'
        : '$day $month';
  }

  /// "الخميس، ١٥ يناير" / "Thursday, 15 January".
  static String weekdayDate(
    DateTime t, {
    String locale = 'ar',
    bool? arabicIndic,
  }) {
    final isAr = locale == 'ar';
    final weekday = isAr ? _arWeekdays[t.weekday % 7] : _enWeekdays[t.weekday % 7];
    return '$weekday، ${date(t, locale: locale, arabicIndic: arabicIndic, withYear: false)}';
  }

  /// "١٥ يناير، ٨:٣٠ م" — notification-style timestamp.
  static String dateTime(
    DateTime t, {
    String locale = 'ar',
    bool? use24Hour,
    bool? arabicIndic,
  }) {
    final isAr = locale == 'ar';
    return '${date(t, locale: locale, arabicIndic: arabicIndic, withYear: false)}'
        '${isAr ? '، ' : ', '}'
        '${timeOfDay(t, locale: locale, use24Hour: use24Hour, arabicIndic: arabicIndic)}';
  }
}
