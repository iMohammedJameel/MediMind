import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/modules/settings/cubit/settings_cubit.dart';
import 'package:medimind/modules/settings/cubit/settings_states.dart';
import 'package:medimind/shared/network/local/cache_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
  });

  group('SettingsCubit', () {
    test('defaults to Arabic + system theme with reminders on', () async {
      final cubit = SettingsCubit();
      expect(cubit.state.locale, 'ar');
      expect(cubit.state.themeMode, 'system');
      expect(cubit.state.notificationsEnabled, isTrue);
    });

    test('setLocale persists and emits', () async {
      final cubit = SettingsCubit();
      await cubit.setLocale('en');
      expect(cubit.state.locale, 'en');
      expect(CacheHelper.getLocale(), 'en');
    });

    test('setThemeModeValue persists and maps to ThemeMode', () async {
      final cubit = SettingsCubit();
      await cubit.setThemeModeValue('dark');
      expect(cubit.state.themeMode, 'dark');
      expect(cubit.state.theme, ThemeMode.dark);
      expect(CacheHelper.getThemeMode(), 'dark');
    });

    test('setNotificationsEnabled persists', () async {
      final cubit = SettingsCubit();
      await cubit.setNotificationsEnabled(false);
      expect(cubit.state.notificationsEnabled, isFalse);
      expect(CacheHelper.getNotificationsEnabled(), isFalse);
    });

    test('locale survives a profile error (single state)', () async {
      final cubit = SettingsCubit();
      await cubit.setLocale('en');
      // Backend rejects/missing -> error, prefs untouched.
      await cubit.deleteAccount(password: 'password1');
      expect(cubit.state.locale, 'en'); // prefs not lost
      expect(cubit.state.error, 'err.deleteAccountUnsupported');
    });

    test('reading prefs persist and emit', () async {
      final cubit = SettingsCubit();
      expect(cubit.state.use24Hour, isFalse); // 12-hour ص/م default
      expect(cubit.state.fontScale, 1.0);

      await cubit.setUse24Hour(true);
      await cubit.setArabicDigits(false);
      await cubit.setFontScale(1.4);

      expect(cubit.state.use24Hour, isTrue);
      expect(cubit.state.arabicDigits, isFalse);
      expect(cubit.state.fontScale, 1.4);
      expect(CacheHelper.getUse24Hour(), isTrue);
      expect(CacheHelper.getArabicDigits(), isFalse);
      expect(CacheHelper.getFontScale(), 1.4);
    });

    test('font scale clamps to 1.0–1.4', () async {
      final cubit = SettingsCubit();
      await cubit.setFontScale(0.5);
      expect(cubit.state.fontScale, 1.0);
      await cubit.setFontScale(3.0);
      expect(cubit.state.fontScale, 1.4);
    });

    test('setCrashReportingEnabled toggles and emits distinct state', () async {
      final cubit = SettingsCubit();
      expect(cubit.state.crashReportingEnabled, isTrue);
      await cubit.setCrashReportingEnabled(false);
      expect(cubit.state.crashReportingEnabled, isFalse);
      expect(CacheHelper.getCrashReportingEnabled(), isFalse);
    });
  });

  test('SettingsState theme getter covers all values', () {
    expect(const SettingsState(themeMode: 'light').theme, ThemeMode.light);
    expect(const SettingsState(themeMode: 'system').theme, ThemeMode.system);
  });
}
