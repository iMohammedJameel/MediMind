import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../l10n/app_strings.dart';
import '../../main.dart' show consumePendingLaunchDoseId, openAlarmForDose;
import '../../services/analytics_service.dart';
import '../../services/biometric_service.dart';
import '../../services/notifications_poller.dart';
import '../../services/push_token_service.dart';
import '../../shared/components/constants.dart';
import '../../shared/network/local/cache_helper.dart';
import '../../shared/styles/colors.dart';

/// Branded animated splash — decides where to go after the entrance animation:
/// onboarding (first launch) → login (no session) → role home.
///
/// When the returning user opted in to biometric unlock, the fingerprint
/// prompt gates the session before any health data is shown.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _scale =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeIn);

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1800), _navigateNext);
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;
    if (!CacheHelper.onboardingSeen) {
      context.go(Routes.onboarding);
    } else if (!CacheHelper.isLoggedIn) {
      context.go(Routes.login);
    } else {
      // Biometric gate: returning user opted in → verify before showing
      // any health data. Cancel/failure falls back to the login screen
      // (password entry still works — biometrics are a convenience, never
      // a lock-out).
      final locale = context.lang;
      final bio = BiometricService.instance;
      if (await bio.isEnabled() && await bio.isSupported()) {
        final ok = await bio.authenticate(locale);
        if (!mounted) return;
        if (!ok) {
          context.go(Routes.login);
          return;
        }
      }
      // Session restored: count the app-open and refresh the device push
      // registration (no-op until FCM lands in the build).
      AnalyticsService.instance.log(AnalyticsService.appOpen);
      PushTokenService.instance.syncToBackend();
      NotificationsPoller.instance.start();
      if (!mounted) return;
      final role = CacheHelper.getRole();
      final isCaregiver = AppConstants.caregiverRoles.contains(role) ||
          role == AppConstants.roleDoctor;
      context.go(isCaregiver
          ? Routes.caregiverHome
          : (role == AppConstants.rolePharmacist
              ? Routes.settings
              : Routes.patientHome));
      final launchDoseId = consumePendingLaunchDoseId();
      if (launchDoseId != null) {
        unawaited(openAlarmForDose(launchDoseId));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/medimind_appicon.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                RichText(
                  text: TextSpan(
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                    children: const [
                      TextSpan(text: 'Medi'),
                      TextSpan(
                          text: 'Mind', style: TextStyle(color: AppColors.primary)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('splash.tagline'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
