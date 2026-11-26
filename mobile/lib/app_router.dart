import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';

export 'routes.dart';

import '../l10n/app_strings.dart';
import 'services/auth_service.dart';
import 'shared/components/constants.dart';
import 'shared/network/local/cache_helper.dart';
import 'modules/login/login_screen.dart';
import 'modules/register/register_screen.dart';
import 'modules/forgot_password/forgot_password_screen.dart';
import 'modules/forgot_password/reset_password_screen.dart';
import 'modules/today/today_screen.dart';
import 'modules/medications/medications_screen.dart';
import 'modules/scan/scan_screen.dart';
import 'modules/adherence/adherence_screen.dart';
import 'modules/settings/settings_screen.dart';
import 'modules/caregiver_patients/caregiver_patients_screen.dart';
import 'modules/patient_detail/patient_detail_screen.dart';
import 'modules/alarm/alarm_screen.dart';
import 'modules/splash/splash_screen.dart';
import 'modules/onboarding/onboarding_screen.dart';
import 'modules/care_circle/care_circle_screen.dart';
import 'modules/notifications/notifications_screen.dart';
import 'modules/privacy/privacy_policy_screen.dart';
import 'modules/profile_setup/profile_setup_screen.dart';
import 'models/dose_event_model.dart';
import 'models/medication_model.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// App-wide route transition: gentle fade + slight upward slide.
CustomTransitionPage<T> _fadeSlide<T>(Widget child) => CustomTransitionPage<T>(
      child: child,
      transitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
    );

final GoRouter appRouter = buildAppRouter();

GoRouter buildAppRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    // Unknown/deep-linked bad routes previously fell through to GoRouter's
    // raw English "Page Not Found" — now a friendly localized dead end.
    // (errorBuilder returns a Widget — NOT a page like pageBuilder above.)
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.travel_explore_rounded,
                  size: 64, color: Color(0xFF678078)),
              const SizedBox(height: 16),
              Text(context.tr('err.notFound'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go(CacheHelper.isLoggedIn
                    ? homeForRole(CacheHelper.getRole())
                    : Routes.login),
                icon: const Icon(Icons.home_outlined),
                label: Text(context.tr('common.backHome')),
              ),
            ],
          ),
        ),
      ),
    ),
    redirect: (context, state) {
      final authed = CacheHelper.isLoggedIn;
      final currentRole = CacheHelper.getRole();
      final loc = state.matchedLocation;
      final publicLoc = loc == Routes.login ||
          loc == Routes.register ||
          loc == Routes.splash ||
          loc == Routes.onboarding ||
          loc == Routes.privacy ||
          loc == Routes.forgotPassword ||
          loc == Routes.resetPassword;

      // Splash decides onboarding-vs-login-vs-home itself.
      if (loc == Routes.splash) return null;
      if (!authed && !publicLoc) return Routes.login;
      if (authed && (loc == Routes.login || loc == Routes.register)) {
        return homeForRole(currentRole);
      }

      // Role isolation
      if (authed && currentRole != null) {
        if (currentRole == AppConstants.rolePharmacist &&
            loc != Routes.unsupportedRole &&
            loc != Routes.settings &&
            loc != Routes.privacy) {
          return Routes.unsupportedRole;
        }
        final isCaregiver = AppConstants.caregiverRoles.contains(currentRole) ||
            currentRole == AppConstants.roleDoctor;
        if (loc.startsWith('/patient') && isCaregiver) {
          return Routes.caregiverHome;
        }
        if (loc.startsWith('/caregiver') && !isCaregiver) {
          return Routes.patientHome;
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        name: 'splash',
        pageBuilder: (_, __) => _fadeSlide(const SplashScreen()),
      ),
      GoRoute(
        path: Routes.onboarding,
        name: 'onboarding',
        pageBuilder: (_, __) => _fadeSlide(const OnboardingScreen()),
      ),
      GoRoute(
        path: Routes.login,
        name: 'login',
        pageBuilder: (_, __) => _fadeSlide(const LoginScreen()),
      ),
      GoRoute(
        path: Routes.register,
        name: 'register',
        pageBuilder: (_, __) => _fadeSlide(const RegisterScreen()),
      ),
      GoRoute(
        path: Routes.privacy,
        name: 'privacy',
        pageBuilder: (_, __) => _fadeSlide(const PrivacyPolicyScreen()),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        name: 'forgotPassword',
        pageBuilder: (_, __) => _fadeSlide(const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: Routes.resetPassword,
        name: 'resetPassword',
        pageBuilder: (_, state) => _fadeSlide(ResetPasswordScreen(
          identifier: state.extra is String ? state.extra! as String : null,
        )),
      ),
      GoRoute(
        path: Routes.profileSetup,
        name: 'profileSetup',
        pageBuilder: (_, __) => _fadeSlide(const ProfileSetupScreen()),
      ),
      GoRoute(
        path: '/patient',
        redirect: (_, __) => Routes.patientHome,
      ),
      GoRoute(
        path: Routes.patientHome,
        name: 'today',
        pageBuilder: (_, __) => _fadeSlide(const TodayScreen()),
      ),
      GoRoute(
        path: Routes.medications,
        name: 'medications',
        pageBuilder: (_, state) => _fadeSlide(
            MedicationsScreen(scanResult: state.uri.queryParameters['scan'])),
      ),
      GoRoute(
        path: Routes.scan,
        name: 'scan',
        pageBuilder: (_, __) => _fadeSlide(const ScanScreen()),
      ),
      GoRoute(
        path: Routes.adherence,
        name: 'adherence',
        pageBuilder: (_, __) => _fadeSlide(const AdherenceScreen()),
      ),
      GoRoute(
        path: Routes.careCircle,
        name: 'careCircle',
        pageBuilder: (_, __) => _fadeSlide(const CareCircleScreen()),
      ),
      GoRoute(
        path: Routes.notifications,
        name: 'notifications',
        pageBuilder: (_, __) => _fadeSlide(const NotificationsScreen()),
      ),
      GoRoute(
        path: Routes.settings,
        name: 'settings',
        pageBuilder: (_, __) => _fadeSlide(const SettingsScreen()),
      ),
      GoRoute(
        path: '/caregiver',
        redirect: (_, __) => Routes.caregiverHome,
      ),
      GoRoute(
        path: Routes.caregiverHome,
        name: 'caregiverPatients',
        pageBuilder: (_, __) => _fadeSlide(const CaregiverPatientsScreen()),
      ),
      GoRoute(
        path: '/caregiver/patients/:id',
        name: 'patientDetail',
        pageBuilder: (_, state) {
          final rel = state.extra is RelationshipModel
              ? state.extra! as RelationshipModel
              : null;
          final name = rel?.patientName ??
              (state.extra is String ? state.extra! as String : null);
          return _fadeSlide(PatientDetailScreen(
            patientId: state.pathParameters['id']!,
            patientName: name,
            patientPhone: rel?.patientPhone,
            emergencyPhone: rel?.emergencyPhone,
          ));
        },
      ),
      GoRoute(
        path: '/alarm/:doseId',
        name: 'alarm',
        // The dose object travels as `extra` when the app is alive; on a
        // cold-start notification tap the screen resolves it by id itself.
        pageBuilder: (_, state) => _fadeSlide(
          AlarmScreen(dose: state.extra is DoseEventModel ? state.extra! as DoseEventModel : null),
        ),
      ),
      GoRoute(
        path: Routes.unsupportedRole,
        name: 'unsupportedRole',
        pageBuilder: (_, __) => _fadeSlide(const _UnsupportedRoleScreen()),
      ),
    ],
  );
}

/// Resolves the initial home route for a given user role.
String homeForRole(String? role) {
  if (role == null) return Routes.login;
  if (role == AppConstants.rolePharmacist) return Routes.unsupportedRole;
  final isCaregiver = AppConstants.caregiverRoles.contains(role) ||
      role == AppConstants.roleDoctor;
  return isCaregiver ? Routes.caregiverHome : Routes.patientHome;
}

class _UnsupportedRoleScreen extends StatelessWidget {
  const _UnsupportedRoleScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_pharmacy_outlined,
                  size: 64, color: Color(0xFF174D3F)),
              const SizedBox(height: 16),
              Text(
                context.tr('auth.pharmacistWebOnly'),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  await AuthService().logout();
                  if (context.mounted) context.go(Routes.login);
                },
                icon: const Icon(Icons.logout),
                label: Text(context.tr('settings.logout')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
