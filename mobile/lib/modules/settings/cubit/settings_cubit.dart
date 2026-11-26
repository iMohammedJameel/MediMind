import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/doses_service.dart';
import '../../../services/local_notifications_service.dart';
import '../../../services/notifications_poller.dart';
import '../../../services/offline_sync_service.dart';
import '../../../services/profile_service.dart';
import '../../../shared/components/constants.dart';
import '../../../shared/network/local/cache_helper.dart';
import '../../../shared/network/remote/dio_helper.dart';
import '../../../shared/utils/safe_emit.dart';
import 'settings_states.dart';

/// App-level settings: locale, theme mode, dose reminders, profile,
/// account deletion. Provided above MaterialApp so the whole tree rebuilds
/// on locale/theme changes.
class SettingsCubit extends Cubit<SettingsState> with SafeEmit<SettingsState> {
  final ProfileService _profileService;

  SettingsCubit({ProfileService? profileService})
      : _profileService = profileService ?? ProfileService(),
        super(SettingsState(
          locale: CacheHelper.getLocale(),
          themeMode: CacheHelper.getThemeMode(),
          notificationsEnabled: CacheHelper.getNotificationsEnabled(),
          use24Hour: CacheHelper.getUse24Hour(),
          arabicDigits: CacheHelper.getArabicDigits(),
          fontScale: CacheHelper.getFontScale(),
          crashReportingEnabled: CacheHelper.getCrashReportingEnabled(),
        ));

  // ---- Prefs ----

  Future<void> setLocale(String locale) async {
    await CacheHelper.setLocale(locale);
    emit(state.copyWith(locale: locale, clearError: true));
  }

  Future<void> setThemeModeValue(String value) async {
    await CacheHelper.setThemeMode(value);
    emit(state.copyWith(themeMode: value, clearError: true));
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await CacheHelper.setNotificationsEnabled(enabled);
    if (!enabled) {
      await LocalNotificationsService.cancelAll();
    } else if (CacheHelper.isLoggedIn && CacheHelper.getRole() == 'PATIENT') {
      try {
        await LocalNotificationsService.ensurePermissionsRequested();
        final doses = await DosesService().todaySchedule();
        await LocalNotificationsService.scheduleDoseReminders(doses);
      } catch (_) {}
    }
    emit(state.copyWith(notificationsEnabled: enabled, clearError: true));
  }

  // ---- Reading & numerals ----

  /// 12-hour ص/م (default) vs 24-hour clock.
  Future<void> setUse24Hour(bool value) async {
    await CacheHelper.setUse24Hour(value);
    emit(state.copyWith(use24Hour: value, clearError: true));
  }

  /// Arabic-Indic digits (١٢٣) vs Latin digits.
  Future<void> setArabicDigits(bool value) async {
    await CacheHelper.setArabicDigits(value);
    emit(state.copyWith(arabicDigits: value, clearError: true));
  }

  /// Font scale 1.0–1.4 (multiplied with the elderly base 1.15 in main.dart).
  Future<void> setFontScale(double value) async {
    final clamped = value.clamp(1.0, 1.4);
    await CacheHelper.setFontScale(clamped);
    emit(state.copyWith(fontScale: clamped, clearError: true));
  }

  /// Anonymous crash-report forwarding (opt-out).
  Future<void> setCrashReportingEnabled(bool value) async {
    await CacheHelper.setCrashReportingEnabled(value);
    emit(state.copyWith(crashReportingEnabled: value, clearError: true));
  }

  // ---- Profile ----

  Future<void> loadProfile() async {
    emit(state.copyWith(profileLoading: true, clearError: true));
    try {
      final profile = await _profileService.myProfile();
      if (profile.firstName.trim().isNotEmpty) {
        await CacheHelper.setFirstName(profile.firstName);
      }
      emit(state.copyWith(profile: profile, profileLoading: false));
    } catch (e) {
      emit(state.copyWith(profileLoading: false, error: apiError(e, 'err.profileLoad')));
    }
  }

  /// Role-aware update: patients can update names, phone, blood type, and
  /// emergency contact; caregivers edit names + phone.
  Future<void> saveProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? bloodType,
    String? emergencyName,
    String? emergencyPhone,
  }) async {
    final isPatient = CacheHelper.getRole() == AppConstants.rolePatient;
    final hasEmergency = (emergencyName != null && emergencyName.isNotEmpty) ||
        (emergencyPhone != null && emergencyPhone.isNotEmpty);
    final payload = {
      if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (isPatient) ...{
        if (bloodType != null && bloodType.isNotEmpty) 'bloodType': bloodType,
        if (hasEmergency)
          'emergencyContact': {
            if (emergencyName != null && emergencyName.isNotEmpty)
              'name': emergencyName,
            if (emergencyPhone != null && emergencyPhone.isNotEmpty)
              'phone': emergencyPhone,
          },
      },
    };

    emit(state.copyWith(profileSaving: true, clearError: true));
    try {
      final updated = await _profileService.updateProfile(payload);
      if (updated.firstName.trim().isNotEmpty) {
        await CacheHelper.setFirstName(updated.firstName);
      }
      // profileSaved=true drives the success snackbar in the screen
      // listener (previously the save had NO visible feedback at all).
      emit(state.copyWith(
          profile: updated, profileSaving: false, profileSaved: true));
    } catch (e) {
      emit(state.copyWith(profileSaving: false, error: apiError(e, 'err.profileSave')));
    }
  }

  // ---- Account ----

  /// Returns true if the account was deleted (and the session cleared).
  /// Requires the account password for re-authentication (Article 21).
  Future<bool> deleteAccount({required String password}) async {
    try {
      await _profileService.deleteAccount(password: password);
      NotificationsPoller.instance.stop();
      await OfflineSyncService.instance.resetDroppedCount();
      await CacheHelper.clearSession();
      // Full local wipe — same contract as logout: cookies + every
      // scheduled dose reminder must not outlive the deleted account.
      try {
        await DioHelper.clearCookies();
        await LocalNotificationsService.cancelAll();
      } catch (_) {}
      return true;
    } catch (e) {
      emit(state.copyWith(error: apiError(e, 'err.deleteAccountUnsupported')));
      return false;
    }
  }
}
