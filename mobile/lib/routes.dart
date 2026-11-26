/// Named route paths — standalone file so both the router and shared
/// components (bottom nav) reference ONE source of truth.
class Routes {
  Routes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const privacy = '/privacy';
  static const profileSetup = '/profile-setup';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';

  // Patient
  static const patientHome = '/patient/today';
  static const medications = '/patient/medications';
  static const scan = '/patient/scan';
  static const adherence = '/patient/adherence';
  static const careCircle = '/patient/care-circle';
  static const settings = '/settings';
  static const notifications = '/notifications';

  // Caregiver
  static const caregiverHome = '/caregiver/patients';
  static String patientDetail(String id) => '/caregiver/patients/$id';

  // Full-screen dose alarm (opened from a notification tap)
  static String alarm(String doseId) => '/alarm/$doseId';

  // Web-only roles (e.g. PHARMACIST)
  static const unsupportedRole = '/unsupported-role';
}
