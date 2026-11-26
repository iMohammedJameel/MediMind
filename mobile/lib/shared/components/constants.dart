/// App-wide constants — no magic values scattered around the codebase.
class AppConstants {
  AppConstants._();

  /// Backend base URL. Android emulator reaches the host via 10.0.2.2.
  /// Override at build time:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080/api/v1
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api/v1',
  );

  /// Resolves relative media paths (e.g. `/uploads/med_123.jpg`) against the
  /// backend origin so `Image.network` works on mobile as well as web.
  static String? resolveMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final apiUri = Uri.tryParse(apiBaseUrl);
    if (apiUri == null || !apiUri.hasScheme || apiUri.host.isEmpty) {
      return trimmed;
    }
    final origin = apiUri.hasPort
        ? '${apiUri.scheme}://${apiUri.host}:${apiUri.port}'
        : '${apiUri.scheme}://${apiUri.host}';
    return trimmed.startsWith('/') ? '$origin$trimmed' : '$origin/$trimmed';
  }

  // ---- API paths ----
  static const String loginPath = '/auth/login';
  static const String registerPath = '/auth/register';
  static const String logoutPath = '/auth/logout';
  static const String refreshPath = '/auth/token/refresh';
  static const String verifyTokenPath = '/auth/verify-token';
  static const String forgotPasswordPath = '/auth/forgot-password';
  static const String resetPasswordPath = '/auth/reset-password';

  static const String dosesPath = '/doses';
  static const String medicationsPath = '/medications';
  static const String scanPath = '/medications/scan';
  static const String refillsPath = '/medications/refills';
  static const String relationshipsPath = '/relationships';
  static const String profilesPath = '/profiles';
  static const String pharmacistsPath = '/profiles/pharmacists';
  static const String uploadMedicationImagePath = '/uploads/medication-image';
  static const String deviceTokenPath = '/notifications/device-token';
  static const String notificationsPath = '/notifications';
  static const String analyticsEventsPath = '/analytics/events';

  /// Self-service account deletion (requires password re-auth).
  static const String deleteAccountPath = '/auth/account';

  // ---- Business rules ----
  /// Dose status values returned by the backend.
  static const doseStatusPending = 'PENDING';
  static const doseStatusTaken = 'TAKEN';
  static const doseStatusMissed = 'MISSED';
  static const doseStatusLate = 'LATE';
  static const doseStatusSkipped = 'SKIPPED';

  // ---- Roles ----
  static const rolePatient = 'PATIENT';
  static const roleFamilyCaregiver = 'FAMILY_CAREGIVER';
  static const roleProfessionalCaregiver = 'PROFESSIONAL_CAREGIVER';
  static const roleDoctor = 'DOCTOR';
  static const rolePharmacist = 'PHARMACIST';

  static const caregiverRoles = [roleFamilyCaregiver, roleProfessionalCaregiver];
}
