import '../shared/components/constants.dart';
import '../shared/network/local/cache_helper.dart';
import '../shared/network/remote/dio_helper.dart';
import 'biometric_service.dart';
import 'local_notifications_service.dart';
import 'notifications_poller.dart';
import 'offline_sync_service.dart';

/// Auth API calls.
class AuthService {
  /// Extracts the session payload from a login/register response.
  /// Backend shape: `data = { accessToken, refreshToken, user: {...} }`
  /// (DioHelper already unwraps the outer `data` envelope).
  static Map<String, dynamic> _sessionOf(dynamic data) {
    if (data is Map) {
      // Login/register responses (sessionData).
      if (data['user'] is Map || data['accessToken'] != null) {
        return data.cast<String, dynamic>();
      }
    }
    return const <String, dynamic>{};
  }

  static String _roleOf(Map<String, dynamic> session) {
    final user = session['user'];
    if (user is Map) {
      final role = user['role'];
      if (role != null) return role.toString();
    }
    // Legacy fallbacks (kept for response-shape drift safety).
    final role = session['role'] ?? session['account'];
    if (role is Map) return (role['role'] ?? AppConstants.rolePatient).toString();
    if (role != null) return role.toString();
    return AppConstants.rolePatient;
  }

  /// Logs in, caches token/role/email, returns the account role.
  Future<String> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final cleanEmail = email?.trim();
    final cleanPhone = phone?.trim();
    final data = await DioHelper.post(AppConstants.loginPath, data: {
      if (cleanEmail != null && cleanEmail.isNotEmpty) 'email': cleanEmail,
      if (cleanPhone != null && cleanPhone.isNotEmpty) 'phone': cleanPhone,
      'password': password,
    });
    final session = _sessionOf(data);
    final role = _roleOf(session);
    final token = (session['accessToken'] ?? session['access_token'])?.toString();
    if (token != null) {
      await CacheHelper.setToken(token);
    }
    await CacheHelper.setRole(role);
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      await CacheHelper.setEmail(cleanEmail);
    }
    final user = session['user'];
    if (user is Map && user['firstName'] != null) {
      await CacheHelper.setFirstName(user['firstName'].toString());
    }
    return role;
  }

  /// Registers a patient. Only real user input is sent — health fields
  /// (birth date, blood type, weight, height) are intentionally NOT
  /// fabricated anymore; the user fills them right after registration in
  /// the profile-setup screen.
  /// Returns the account role so the caller can route the post-signup flow.
  Future<String> registerPatient({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String countryCode,
    required String phone,
  }) async {
    final cleanEmail = email.trim();
    final cleanPhone = phone.trim();
    final data = await DioHelper.post(AppConstants.registerPath, data: {
      'role': AppConstants.rolePatient,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'credentials': {'email': cleanEmail, 'password': password},
      'nationalNumber': {'code': countryCode, 'number': cleanPhone},
      'phone': cleanPhone,
    });
    return await _cacheSession(_sessionOf(data), email: cleanEmail);
  }

  Future<String> registerFamilyCaregiver({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String countryCode,
    required String phone,
  }) async {
    final cleanEmail = email.trim();
    final cleanPhone = phone.trim();
    final data = await DioHelper.post(AppConstants.registerPath, data: {
      'role': AppConstants.roleFamilyCaregiver,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'credentials': {'email': cleanEmail, 'password': password},
      'nationalNumber': {'code': countryCode, 'number': cleanPhone},
      'phone': cleanPhone,
    });
    return await _cacheSession(_sessionOf(data), email: cleanEmail);
  }

  /// Caches the session the backend returns from registration (it already
  /// contains an access token — no second login round-trip needed).
  Future<String> _cacheSession(Map<String, dynamic> session,
      {required String email}) async {
    final role = _roleOf(session);
    final token = session['accessToken']?.toString();
    if (token != null && token.isNotEmpty) {
      await CacheHelper.setToken(token);
    }
    await CacheHelper.setRole(role);
    if (email.isNotEmpty) await CacheHelper.setEmail(email);
    final user = session['user'];
    if (user is Map && user['firstName'] != null) {
      await CacheHelper.setFirstName(user['firstName'].toString());
    }
    return role;
  }

  Future<void> logout() async {
    try {
      await DioHelper.post(AppConstants.logoutPath);
    } finally {
      NotificationsPoller.instance.stop();
      await OfflineSyncService.instance.resetDroppedCount();
      await CacheHelper.clearSession();
      // Also drop the persisted refresh cookie — full local session wipe.
      try {
        await DioHelper.clearCookies();
      } catch (_) {}
      // And stop every dose reminder still scheduled for the outgoing
      // account — otherwise the next user of this device keeps getting
      // alarms for someone else's medications.
      try {
        await LocalNotificationsService.cancelAll();
      } catch (_) {}
      // The biometric opt-in is account-scoped: the next user of this
      // device must NOT be auto-unlocked into the outgoing session.
      try {
        await BiometricService.instance.clear();
      } catch (_) {}
    }
  }

  /// Password recovery — step 1: ask the backend to send a reset code to the
  /// account tied to [identifier] (email OR phone — same as login).
  /// Always succeeds from the UI's perspective when the request was accepted;
  /// a wrong identifier is reported by the backend as a 4xx.
  Future<void> requestPasswordReset(String identifier) =>
      DioHelper.post(AppConstants.forgotPasswordPath, data: {
        'identifier': identifier.trim(),
      });

  /// Password recovery — step 2: verify the 6-digit code and set the new
  /// password in one round-trip.
  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  }) =>
      DioHelper.post(AppConstants.resetPasswordPath, data: {
        'identifier': identifier.trim(),
        'code': code.trim(),
        'newPassword': newPassword,
      });
}
