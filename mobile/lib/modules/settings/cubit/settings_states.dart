import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../../../models/profile_model.dart';

/// Single immutable state — locale/theme/reminders/reading prefs always stay
/// populated so the MaterialApp shell never loses them during profile
/// operations.
class SettingsState extends Equatable {
  final String locale; // 'ar' | 'en'
  final String themeMode; // 'light' | 'dark' | 'system'
  final bool notificationsEnabled;

  // Reading & numerals (Egyptian elderly market).
  final bool use24Hour; // false = 12-hour ص/م
  final bool arabicDigits; // true = ١٢٣
  final double fontScale; // 1.0 – 1.4 (on top of the 1.15 elderly base)
  final bool crashReportingEnabled;

  final ProfileModel? profile;
  final bool profileLoading;
  final bool profileSaving;
  /// True right after a successful profile save (drives the success
  /// snackbar in the screen listener; any other state change resets it).
  final bool profileSaved;
  final String? error; // translation key or raw server message

  const SettingsState({
    this.locale = 'ar',
    this.themeMode = 'system',
    this.notificationsEnabled = true,
    this.use24Hour = false,
    this.arabicDigits = true,
    this.fontScale = 1.0,
    this.crashReportingEnabled = true,
    this.profile,
    this.profileLoading = false,
    this.profileSaving = false,
    this.profileSaved = false,
    this.error,
  });

  SettingsState copyWith({
    String? locale,
    String? themeMode,
    bool? notificationsEnabled,
    bool? use24Hour,
    bool? arabicDigits,
    double? fontScale,
    bool? crashReportingEnabled,
    ProfileModel? profile,
    bool? profileLoading,
    bool? profileSaving,
    bool? profileSaved,
    String? error,
    bool clearError = false,
  }) =>
      SettingsState(
        locale: locale ?? this.locale,
        themeMode: themeMode ?? this.themeMode,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        use24Hour: use24Hour ?? this.use24Hour,
        arabicDigits: arabicDigits ?? this.arabicDigits,
        fontScale: fontScale ?? this.fontScale,
        crashReportingEnabled:
            crashReportingEnabled ?? this.crashReportingEnabled,
        profile: profile ?? this.profile,
        profileLoading: profileLoading ?? false,
        profileSaving: profileSaving ?? false,
        profileSaved: profileSaved ?? false,
        error: clearError ? null : (error ?? this.error),
      );

  ThemeMode get theme => switch (themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  @override
  List<Object?> get props => [
        locale,
        themeMode,
        notificationsEnabled,
        use24Hour,
        arabicDigits,
        fontScale,
        crashReportingEnabled,
        profile,
        profileLoading,
        profileSaving,
        profileSaved,
        error,
      ];
}
