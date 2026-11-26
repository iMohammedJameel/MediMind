import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsBinding;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';
import 'models/dose_event_model.dart';
import 'services/crash_reporter_service.dart';
import 'services/dose_alarm_watchdog.dart';
import 'services/doses_service.dart';
import 'services/local_notifications_service.dart';
import 'services/notifications_poller.dart';
import 'services/offline_sync_service.dart';
import 'services/profile_service.dart';
import 'shared/bloc_observer.dart';
import 'shared/network/local/cache_helper.dart';
import 'shared/network/remote/dio_helper.dart';
import 'shared/styles/theme.dart';
import 'modules/connectivity/cubit/connectivity_cubit.dart';
import 'modules/settings/cubit/settings_cubit.dart';
import 'modules/settings/cubit/settings_states.dart';
import 'shared/components/connectivity_banner.dart';
import 'shared/components/components.dart';

void main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // QA builds only (flutter build web --dart-define=QA_SEMANTICS=true):
    // exposes the full a11y semantics tree so browser automation can read
    // and drive every widget. Never enabled in production builds.
    if (const bool.fromEnvironment('QA_SEMANTICS', defaultValue: false)) {
      SemanticsBinding.instance.ensureSemantics();
    }

    // Global error handlers — nothing should white-screen silently.
    // Every failure is captured by CrashReporterService: persisted on-device
    // (ring buffer) + forwarded to backend analytics when the user opted in.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(CrashReporterService.instance.logFlutterError(details));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(CrashReporterService.instance
          .logError(error, stack: stack.toString(), context: 'zone'));
      return true;
    };

    await CrashReporterService.instance.init();

    await CacheHelper.init();
    OfflineSyncService.instance.refreshDroppedNotifier();
    DioHelper.init();

    await LocalNotificationsService.init();
    LocalNotificationsService.onDoseTapped = openAlarmForDose;
    DoseAlarmWatchdog.instance.canTrigger = () =>
        CacheHelper.isLoggedIn &&
        CacheHelper.getNotificationsEnabled() &&
        CacheHelper.getRole() == 'PATIENT';
    DoseAlarmWatchdog.instance.onDoseDue =
        (dose) => openAlarmForDose(dose.id, prefetchedDose: dose);

    Bloc.observer = AppBlocObserver();

    runApp(const MediMindApp());

    // Session-expiry escape hatch: when a 401 + failed refresh clears the
    // session, take the user to Login instead of leaving them stranded on
    // an authenticated screen full of raw errors.
    DioHelper.onSessionExpired = () {
      NotificationsPoller.instance.stop();
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) ctx.go(Routes.login);
    };

    // Tell the backend which timezone this device lives in — dose times are
    // scheduled in the PATIENT's wall-clock time (DST-aware). Non-blocking.
    if (CacheHelper.isLoggedIn && CacheHelper.getRole() == 'PATIENT') {
      unawaited(_syncDeviceTimezone());
    }

    // Cold start via notification tap: the payload only carries the dose id.
    unawaited(_openAlarmFromLaunch());
  }, (error, stack) {
    // runZonedGuarded fallback (should not normally fire once
    // PlatformDispatcher.onError is installed — kept as last resort).
    debugPrint('🔥 Zone error: $error');
    unawaited(CrashReporterService.instance
        .logError(error, stack: stack.toString(), context: 'runZoned'));
  });
}

/// One-way timezone sync (patient role only) — the device's IANA identifier
/// (e.g. Africa/Cairo) lets the backend schedule doses in the patient's
/// wall-clock time, DST-aware. Africa/Cairo fallback applies server-side,
/// so failures here are intentionally ignored.
Future<void> _syncDeviceTimezone() async {
  // flutter_timezone has no web implementation — the call would throw
  // MissingPluginException on the web target (harmless but noisy).
  if (kIsWeb) return;
  try {
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    final identifier = tzInfo.identifier;
    if (identifier.isNotEmpty && identifier.contains('/')) {
      await ProfileService().syncTimezone(identifier);
    }
  } catch (_) {
    // Non-blocking by design.
  }
}

String? _pendingLaunchDoseId;

/// Returns & clears a cold-start notification dose id (used by SplashScreen
/// after auth/biometrics settle so `context.go` never wipes AlarmScreen).
String? consumePendingLaunchDoseId() {
  final id = _pendingLaunchDoseId;
  _pendingLaunchDoseId = null;
  return id;
}

/// Notification tap or due foreground alarm -> open AlarmScreen for [doseEventId].
/// Guards against pushing duplicate alarm routes when one is already visible.
Future<void> openAlarmForDose(
  String doseEventId, {
  DoseEventModel? prefetchedDose,
}) async {
  if (!CacheHelper.isLoggedIn) return;
  final currentPath = appRouter.routeInformationProvider.value.uri.path;
  if (currentPath == Routes.alarm(doseEventId)) return;
  final dose = prefetchedDose ?? await resolveDose(doseEventId);
  final ctx = rootNavigatorKey.currentContext;
  if (ctx != null && ctx.mounted) {
    ctx.push(Routes.alarm(doseEventId), extra: dose);
  }
}

Future<DoseEventModel?> resolveDose(String doseEventId) async {
  try {
    final doses = await DosesService().todaySchedule();
    return doses.where((d) => d.id == doseEventId).firstOrNull;
  } catch (_) {
    // Offline or expired session — the app opens on its regular home screen.
    return null;
  }
}

Future<void> _openAlarmFromLaunch() async {
  final payload = await LocalNotificationsService.launchPayload();
  if (payload == null) return;
  final currentPath = appRouter.routeInformationProvider.value.uri.path;
  if (currentPath == Routes.splash) {
    _pendingLaunchDoseId = payload;
    return;
  }
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await openAlarmForDose(payload);
}

class MediMindApp extends StatefulWidget {
  const MediMindApp({super.key});

  @override
  State<MediMindApp> createState() => _MediMindAppState();
}

class _MediMindAppState extends State<MediMindApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(DoseAlarmWatchdog.instance.checkDueOnResume());
    if (CacheHelper.isLoggedIn &&
        CacheHelper.getRole() == 'PATIENT' &&
        CacheHelper.getNotificationsEnabled()) {
      unawaited(_resyncPatientReminders());
    }
  }

  Future<void> _resyncPatientReminders() async {
    try {
      final doses = await DosesService().todaySchedule();
      await LocalNotificationsService.scheduleDoseReminders(doses);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SettingsCubit()),
        BlocProvider(create: (_) => ConnectivityCubit()),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          return MaterialApp.router(
            title: 'MediMind',
            debugShowCheckedModeBanner: false,
            routerConfig: appRouter,
            // RTL for Arabic, LTR for English — mirrors automatically.
            locale: Locale(settings.locale),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            builder: (context, child) {
              // Elderly-friendly base scale (1.15) multiplied with the user's
              // accessibility scale (1.0–1.4, Settings) and the system font
              // scale.
              final systemFactor =
                  MediaQuery.textScalerOf(context).scale(100) / 100;
              final totalScale =
                  (1.15 * settings.fontScale * systemFactor).clamp(0.8, 2.0);
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(totalScale)),
                child: ConnectivityBannerWrapper(
                  child: MediMindBackground(child: child ?? const SizedBox.shrink()),
                ),
              );
            },
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.theme,
          );
        },
      ),
    );
  }
}
