import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences wrapper — cached instance, sync access after [init].
///
/// The access token lives in flutter_secure_storage (never plaintext prefs);
/// an in-memory mirror keeps the existing sync [getToken] API for the Dio
/// interceptor and router guards.
class CacheHelper {
  static late SharedPreferences _prefs;
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static String? _tokenMirror;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // One-time migration from the old plaintext token storage.
    final legacy = _prefs.getString('token');
    if (legacy != null && legacy.isNotEmpty) {
      await _secure.write(key: 'token', value: legacy);
      await _prefs.remove('token');
      _tokenMirror = legacy;
    } else {
      try {
        _tokenMirror = await _secure.read(key: 'token');
      } catch (_) {
        // Secure storage unavailable (e.g. test env) — treat as logged out.
        _tokenMirror = null;
      }
    }
  }

  // ---- Auth session ----
  static String? getToken() => _tokenMirror;
  static Future<void> setToken(String? token) async {
    _tokenMirror = token;
    if (token == null) {
      await _secure.delete(key: 'token');
    } else {
      await _secure.write(key: 'token', value: token);
    }
  }

  /// Generic secure-storage read (biometric opt-in flag, etc.).
  static Future<String?> secureRead(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  /// Generic secure-storage write.
  static Future<void> secureWrite(String key, String value) async {
    await _secure.write(key: key, value: value);
  }

  /// Generic secure-storage delete.
  static Future<void> secureDelete(String key) async {
    try {
      await _secure.delete(key: key);
    } catch (_) {}
  }

  static String? getRole() => _prefs.getString('role');
  static Future<void> setRole(String? role) async {
    if (role == null) {
      await _prefs.remove('role');
    } else {
      await _prefs.setString('role', role);
    }
  }

  static String? getEmail() => _prefs.getString('email');
  static Future<void> setEmail(String? email) async {
    if (email == null) {
      await _prefs.remove('email');
    } else {
      await _prefs.setString('email', email);
    }
  }

  static String? getFirstName() {
    try {
      return _prefs.getString('first_name');
    } catch (_) {
      return null;
    }
  }

  static Future<void> setFirstName(String? name) async {
    if (name == null || name.trim().isEmpty) {
      await _prefs.remove('first_name');
    } else {
      await _prefs.setString('first_name', name.trim());
    }
  }

  static String? get fcmToken => _prefs.getString('fcm_token');
  static Future<void> setFcmToken(String token) =>
      _prefs.setString('fcm_token', token);

  static Future<void> clearSession() async {
    await setToken(null);
    await _prefs.remove('role');
    await _prefs.remove('email');
    await _prefs.remove('first_name');
    // Privacy + data-integrity: wipe ALL cached health data AND the offline
    // action queue — the next account on this device must never see (or
    // worse: sync under its own token!) the previous user's dose actions.
    await _prefs.remove(cachedDosesKey);
    await _prefs.remove(cachedMedicationsKey);
    await _prefs.remove(pendingSyncActionsKey);
    await _prefs.remove(offlineDroppedCountKey);
    await _prefs.remove('${adherenceCachePrefix}week');
    await _prefs.remove('${adherenceCachePrefix}month');
    await _prefs.remove('fcm_token');
    // Local reminder registries (scheduled ids + active snoozes).
    await _prefs.remove(scheduledDoseIdsKey);
    await _prefs.remove(activeSnoozesKey);
    await _prefs.remove(savedDeliveryAddressKey);
  }

  /// Shared cache keys (so logout can wipe them all).
  static const String cachedDosesKey = 'cached_doses_today';
  static const String cachedMedicationsKey = 'cached_medications';
  static const String pendingSyncActionsKey = 'pending_sync_actions';
  static const String adherenceCachePrefix = 'adherence_cache_';
  static const String notifPermissionAskedKey = 'notif_permission_asked';
  static const String offlineDroppedCountKey = 'offline_sync_dropped_count';
  static const String savedDeliveryAddressKey = 'saved_delivery_address';

  static String? getSavedDeliveryAddress() =>
      _prefs.getString(savedDeliveryAddressKey);
  static Future<void> setSavedDeliveryAddress(String json) =>
      _prefs.setString(savedDeliveryAddressKey, json);

  /// Reminder scheduling registries (LocalNotificationsService):
  /// [scheduledDoseIdsKey] holds the ids currently scheduled with the OS so
  /// stale reminders (deleted/deactivated medications) can be cancelled on
  /// the next sync; [activeSnoozesKey] maps doseId → snooze-fire time so a
  /// refresh never kills a pending snooze.
  static const String scheduledDoseIdsKey = 'scheduled_dose_ids';
  static const String activeSnoozesKey = 'active_snoozes';

  static bool get notifPermissionAsked =>
      _prefs.getBool(notifPermissionAskedKey) ?? false;
  static Future<void> setNotifPermissionAsked() =>
      _prefs.setBool(notifPermissionAskedKey, true);

  static bool get isLoggedIn => getToken() != null;

  // ---- Locale ----
  static String getLocale() {
    final saved = _prefs.getString('locale');
    if (saved != null && saved.isNotEmpty) return saved;

    // Arabic-first product default (Egyptian elderly market). The user can
    // switch to English at any time from Settings; the choice persists.
    return 'ar';
  }
  static Future<void> setLocale(String locale) =>
      _prefs.setString('locale', locale);

  // ---- Theme ----
  static String getThemeMode() => _prefs.getString('theme_mode') ?? 'system';
  static Future<void> setThemeMode(String mode) =>
      _prefs.setString('theme_mode', mode);

  // ---- Dose reminders on this device ----
  static bool getNotificationsEnabled() =>
      _prefs.getBool('notifications_enabled') ?? true;
  static Future<void> setNotificationsEnabled(bool enabled) =>
      _prefs.setBool('notifications_enabled', enabled);

  // ---- Reading & numerals (Egyptian elderly market) ----
  /// 12-hour (ص/م) is the default; users can switch to 24-hour.
  static bool getUse24Hour() => _prefs.getBool('use_24_hour') ?? false;
  static Future<void> setUse24Hour(bool value) =>
      _prefs.setBool('use_24_hour', value);

  /// Arabic-Indic digits (١٢٣) — default ON for the Arabic locale.
  /// [getArabicDigitsPref] exposes the raw stored choice (null = never set)
  /// so formatters can default per the locale being formatted.
  static bool? getArabicDigitsPref() => _prefs.getBool('arabic_digits');

  static bool getArabicDigits() {
    final stored = getArabicDigitsPref();
    if (stored != null) return stored;
    return getLocale() == 'ar';
  }

  static Future<void> setArabicDigits(bool value) =>
      _prefs.setBool('arabic_digits', value);

  /// User font scale on top of the system scale (1.0 – 1.4, step 0.05).
  /// The elderly base scale (1.15) is applied in main.dart.
  static double getFontScale() {
    final v = _prefs.getDouble('font_scale');
    if (v == null) return 1.0;
    return v < 1.0 ? 1.0 : (v > 1.4 ? 1.4 : v);
  }

  static Future<void> setFontScale(double value) => _prefs
      .setDouble('font_scale', value < 1.0 ? 1.0 : (value > 1.4 ? 1.4 : value));

  /// Anonymous crash-report forwarding to the backend (opt-out in Settings).
  static bool getCrashReportingEnabled() =>
      _prefs.getBool('crash_reporting_enabled') ?? true;
  static Future<void> setCrashReportingEnabled(bool value) =>
      _prefs.setBool('crash_reporting_enabled', value);

  // ---- Onboarding ----
  static bool get onboardingSeen => _prefs.getBool('onboarding_seen') ?? false;
  static Future<void> setOnboardingSeen() =>
      _prefs.setBool('onboarding_seen', true);

  // ---- Generic ----
  static String? getString(String key) => _prefs.getString(key);
  static Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  static List<String> getStringList(String key) => _prefs.getStringList(key) ?? [];
  static Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);
  static Future<void> remove(String key) => _prefs.remove(key);

  /// Clears cached week/month adherence ranges when a dose action changes
  /// today's totals so the Adherence tab refetches fresh stats.
  static Future<void> invalidateAdherenceCaches() async {
    try {
      await _prefs.remove('${adherenceCachePrefix}week');
      await _prefs.remove('${adherenceCachePrefix}month');
    } catch (_) {
      // Cache unavailable (e.g. unit tests) — non-fatal.
    }
  }
}

/// Dio errors surfaced to the UI layer as readable Arabic/English messages.
/// [statusCode]/[code] let callers distinguish server rejections (4xx) from
/// connectivity problems (null) — e.g. the offline sync queue.
class ApiFailure implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  const ApiFailure(this.message, {this.statusCode, this.code});

  /// The server processed and definitively rejected the request (4xx).
  bool get isDefinitiveRejection =>
      statusCode != null && statusCode! >= 400 && statusCode! < 500;

  bool get isNetworkError =>
      code == null && statusCode == null;

  @override
  String toString() => 'ApiFailure($statusCode/$code): $message';
}

/// Cubit-side error mapper: real server message when we have one,
/// otherwise the localized fallback key. Screens render via `trv()`.
String apiError(Object e, String fallbackKey) =>
    e is ApiFailure ? e.message : fallbackKey;

extension DioErrorX on DioException {
  bool get isUnauthorized => response?.statusCode == 401;
}
