import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medimind/l10n/app_strings.dart';
import 'package:medimind/models/dose_event_model.dart';
import 'package:medimind/modules/adherence/adherence_screen.dart';
import 'package:medimind/modules/alarm/alarm_screen.dart';
import 'package:medimind/modules/care_circle/care_circle_screen.dart';
import 'package:medimind/modules/caregiver_patients/caregiver_patients_screen.dart';
import 'package:medimind/modules/connectivity/cubit/connectivity_cubit.dart';
import 'package:medimind/modules/forgot_password/forgot_password_screen.dart';
import 'package:medimind/modules/forgot_password/reset_password_screen.dart';
import 'package:medimind/modules/login/login_screen.dart';
import 'package:medimind/modules/medications/medications_screen.dart';
import 'package:medimind/modules/notifications/notifications_screen.dart';
import 'package:medimind/modules/onboarding/onboarding_screen.dart';
import 'package:medimind/modules/patient_detail/patient_detail_screen.dart';
import 'package:medimind/modules/privacy/privacy_policy_screen.dart';
import 'package:medimind/modules/profile_setup/profile_setup_screen.dart';
import 'package:medimind/modules/register/register_screen.dart';
import 'package:medimind/modules/scan/scan_screen.dart';
import 'package:medimind/modules/settings/cubit/settings_cubit.dart';
import 'package:medimind/modules/settings/cubit/settings_states.dart';
import 'package:medimind/modules/settings/settings_screen.dart';
import 'package:medimind/modules/today/today_screen.dart';
import 'package:medimind/services/auth_service.dart';
import 'package:medimind/services/offline_sync_service.dart';
import 'package:medimind/shared/components/components.dart';
import 'package:medimind/shared/components/connectivity_banner.dart';
import 'package:medimind/shared/network/local/cache_helper.dart';
import 'package:medimind/shared/network/remote/dio_helper.dart';
import 'package:medimind/shared/styles/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _QaHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _QaHttpClient();
}

class _QaHttpClient implements HttpClient {
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _QaHttpRequest(method, url);
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _QaHttpRequest implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;
  _QaHttpRequest(this.method, this.uri);

  @override
  final HttpHeaders headers = _QaHeaders();
  @override
  Encoding encoding = utf8;
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = true;
  final List<int> _body = [];
  Future<HttpClientResponse>? _resFuture;

  @override
  void add(List<int> data) => _body.addAll(data);
  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _body.addAll(chunk);
    }
  }

  @override
  Future<HttpClientResponse> get done => close();

  @override
  Future<HttpClientResponse> close() => _resFuture ??= _buildResponse();

  Future<HttpClientResponse> _buildResponse() async {
    final p = uri.path.replaceFirst('/api/v1', '');
    final bodyStr = utf8.decode(_body, allowMalformed: true);
    dynamic payload;
    final now = DateTime.now();
    final todayIso =
        DateTime(now.year, now.month, now.day, 8, 0).toIso8601String();
    final laterIso =
        DateTime(now.year, now.month, now.day, 21, 0).toIso8601String();

    if (p == '/auth/login') {
      final isCg = bodyStr.contains('caregiver');
      payload = {
        'accessToken': isCg ? 'cg-tok' : 'pt-tok',
        'user': {
          '_id': isCg ? 'cg-1' : 'patient-1',
          'firstName': isCg ? 'منى' : 'أحمد',
          'lastName': isCg ? 'أحمد' : 'محمود عبد الرحمن',
          'email': isCg ? 'caregiver@medimind.app' : 'patient@medimind.app',
          'phone': isCg ? '01011112222' : '01012345678',
          'role': isCg ? 'FAMILY_CAREGIVER' : 'PATIENT',
        },
      };
    } else if (p == '/doses') {
      payload = [
        {
          'doseEventId': 'd-1',
          'medicationId': {'_id': 'm-1', 'name': 'Concor 5mg Bisoprolol'},
          'scheduledFor': todayIso,
          'status': 'TAKEN',
        },
        {
          'doseEventId': 'd-2',
          'medicationId': {'_id': 'm-2', 'name': 'Glucophage 1000mg XR'},
          'scheduledFor': laterIso,
          'status': 'PENDING',
        },
        {
          'doseEventId': 'd-3',
          'medicationId': {'_id': 'm-3', 'name': 'Amaryl 2mg'},
          'scheduledFor': todayIso,
          'status': 'MISSED',
        },
      ];
    } else if (p == '/medications') {
      payload = [
        {
          '_id': 'm-1',
          'name': 'Concor 5mg',
          'formType': 'TABLET',
          'isActive': true,
          'isChronic': true,
          'schedule': {
            'frequency': 'DAILY',
            'dosesPerDay': 1,
            'firstDoseTime': '08:00',
            'timesOfDay': ['08:00'],
          },
          'inventory': {'currentQuantity': 4, 'refillThreshold': 5, 'doseAmount': 1},
          'instructions': {'relationToMeals': 'BEFORE_MEALS', 'notes': 'Morning'},
        },
        {
          '_id': 'm-2',
          'name': 'Glucophage 1000mg XR Extended Release',
          'formType': 'TABLET',
          'isActive': true,
          'isChronic': true,
          'schedule': {
            'frequency': 'DAILY',
            'dosesPerDay': 2,
            'firstDoseTime': '09:00',
            'timesOfDay': ['09:00', '21:00'],
          },
          'inventory': {'currentQuantity': 28, 'refillThreshold': 7, 'doseAmount': 1},
          'instructions': {'relationToMeals': 'AFTER_MEALS', 'notes': 'After food'},
        },
      ];
    } else if (p == '/medications/refills') {
      payload = [
        {
          '_id': 'rf-1',
          'medicationId': {'_id': 'm-1', 'name': 'Concor 5mg'},
          'targetPharmacyId': {'_id': 'ph-1', 'pharmacyName': 'صيدلية العزبي'},
          'quantityRequested': 30,
          'fulfillmentType': 'DELIVERY',
          'orderStatus': 'SUBMITTED',
          'createdAt': todayIso,
        },
      ];
    } else if (p == '/profiles/pharmacists') {
      payload = [
        {
          '_id': 'ph-1',
          'pharmacyName': 'صيدلية العزبي - المعادي',
          'address': {'city': 'المعادي', 'governorate': 'القاهرة'},
          'is24Hours': true,
          'offersDelivery': true,
        },
      ];
    } else if (p == '/relationships') {
      payload = [
        {
          '_id': 'rel-1',
          'status': 'ACCEPTED',
          'relation': 'ابنة',
          'caregiverId': {
            '_id': 'cg-1',
            'firstName': 'منى',
            'lastName': 'أحمد',
            'email': 'caregiver@medimind.app',
            'phone': '01011112222',
          },
          'patientId': {
            '_id': 'patient-1',
            'firstName': 'أحمد',
            'lastName': 'محمود عبد الرحمن',
            'email': 'patient@medimind.app',
            'phone': '01012345678',
            'emergencyPhone': '01098765432',
          },
          'permissions': {'viewAdherence': true, 'receiveMissedAlerts': true},
        },
      ];
    } else if (p == '/notifications/unread-count') {
      payload = {'unreadCount': 2};
    } else if (p == '/notifications') {
      payload = [
        {
          '_id': 'n-1',
          'title': 'Dose reminder',
          'titleAr': 'تذكير بالجرعة',
          'message': 'Time for your Concor 5mg dose',
          'messageAr': 'حان موعد جرعة Concor 5mg',
          'type': 'DOSE_REMINDER',
          'isRead': false,
          'createdAt': todayIso,
        },
      ];
    } else if (p.startsWith('/profiles/')) {
      payload = {
        'user': {
          'firstName': 'أحمد',
          'lastName': 'محمود',
          'email': 'patient@medimind.app',
          'phone': '01012345678',
        },
        'bloodType': 'O+',
        'gender': 'MALE',
        'emergencyContact': {'name': 'منى أحمد', 'phone': '01011112222'},
      };
    } else {
      payload = {};
    }

    final bytes = utf8.encode(jsonEncode({'success': true, 'data': payload}));
    return _QaHttpResponse(200, bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _QaHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  final int statusCode;
  final List<int> _bytes;
  _QaHttpResponse(this.statusCode, this._bytes);

  @override
  int get contentLength => _bytes.length;
  @override
  String get reasonPhrase => 'OK';
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  HttpHeaders get headers => _QaHeaders();
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _QaHeaders implements HttpHeaders {
  final Map<String, List<String>> _map = {'content-type': ['application/json']};
  @override
  List<String>? operator [](String name) => _map[name.toLowerCase()];
  @override
  String? value(String name) => _map[name.toLowerCase()]?.firstOrNull;
  @override
  ContentType? get contentType => ContentType.json;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _map[name.toLowerCase()] = [value.toString()];
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      _map.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _map.forEach(action);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const configs = <(String, Size, double)>[
    ('320x568@1.61', Size(320, 568), 1.61),
    ('360x640@1.15', Size(360, 640), 1.15),
    ('390x844@1.15', Size(390, 844), 1.15),
    ('768x1024@1.61', Size(768, 1024), 1.61),
  ];
  const locales = ['ar', 'en'];

  setUpAll(() async {
    HttpOverrides.global = _QaHttpOverrides();
    SharedPreferences.setMockInitialValues({'locale': 'ar'});
    FlutterSecureStorage.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
      MockStreamHandler.inline(
        onListen: (arguments, events) => events.success(['wifi']),
      ),
    );
    for (final ch in [
      'dev.fluttercommunity.plus/connectivity',
      'com.ryanheise.just_audio.methods',
      'com.ryanheise.audio_session',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async {
        if (call.method == 'check') return ['wifi'];
        if (ch == 'com.ryanheise.just_audio.methods') return <String, dynamic>{};
        return null;
      });
    }
    await CacheHelper.init();
    await DioHelper.init();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Widget child,
    required Size size,
    required String locale,
    required double textScale,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await CacheHelper.setLocale(locale);
    final router = GoRouter(
      initialLocation: '/target',
      routes: [
        GoRoute(
          path: '/target',
          builder: (_, __) => child,
        ),
        GoRoute(
          path: '/:rest(.*)',
          builder: (_, state) => Scaffold(
            body: Center(child: Text('Navigated: ${state.uri}')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SettingsCubit()),
          BlocProvider(create: (_) => ConnectivityCubit()),
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settings) {
            return MaterialApp.router(
              routerConfig: router,
              debugShowCheckedModeBanner: false,
              locale: Locale(locale),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                DefaultMaterialLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
              ],
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeMode,
              builder: (context, c) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: ConnectivityBannerWrapper(
                  child: MediMindBackground(
                      child: c ?? const SizedBox.shrink()),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  // ---- 1. Pre-Auth & Utility Screens ----
  final publicScreens = <(String, Widget Function())>[
    ('OnboardingScreen', () => const OnboardingScreen()),
    ('LoginScreen', () => const LoginScreen()),
    ('RegisterScreen', () => const RegisterScreen()),
    ('ForgotPasswordScreen', () => const ForgotPasswordScreen()),
    ('ResetPasswordScreen', () => const ResetPasswordScreen(identifier: '01012345678')),
    ('ProfileSetupScreen', () => const ProfileSetupScreen()),
    ('PrivacyPolicyScreen', () => const PrivacyPolicyScreen()),
    ('ScanScreen', () => const ScanScreen()),
    (
      'AlarmScreen_Active',
      () => AlarmScreen(
            dose: DoseEventModel(
              id: 'dose-qa-1',
              medicationId: 'med-qa-1',
              medicationName: 'أملوديبين 5mg - Amlodipine Extended Release',
              scheduledFor: DateTime(2026, 11, 26, 8, 0),
              status: 'PENDING',
            ),
          )
    ),
    ('AlarmScreen_NullDose', () => const AlarmScreen(dose: null)),
  ];

  for (final (name, builder) in publicScreens) {
    for (final (sizeLabel, size, scale) in configs) {
      for (final locale in locales) {
        testWidgets('QA [$name] $sizeLabel $locale', (tester) async {
          await pumpScreen(
            tester,
            child: builder(),
            size: size,
            locale: locale,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  // ---- 2. Populated Patient Screens & Modals ----
  group('Patient Regression Matrix', () {
    setUpAll(() async {
      await AuthService().login(
        email: 'patient@medimind.app',
        password: 'Pass@123',
      );
    });

    final patientScreens = <(String, Widget Function())>[
      ('TodayScreen', () => const TodayScreen()),
      ('MedicationsScreen', () => const MedicationsScreen()),
      ('AdherenceScreen', () => const AdherenceScreen()),
      ('CareCircleScreen', () => const CareCircleScreen()),
      ('NotificationsScreen', () => const NotificationsScreen()),
      ('SettingsScreen', () => const SettingsScreen()),
    ];

    for (final (name, builder) in patientScreens) {
      for (final (sizeLabel, size, scale) in configs) {
        for (final locale in locales) {
          testWidgets('QA [$name] $sizeLabel $locale', (tester) async {
            await pumpScreen(
              tester,
              child: builder(),
              size: size,
              locale: locale,
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('QA [Medications Modals: Add, Edit, Refill] 320x568@1.61 ar & en',
        (tester) async {
      for (final loc in locales) {
        await pumpScreen(
          tester,
          child: const MedicationsScreen(),
          size: const Size(320, 568),
          locale: loc,
          textScale: 1.61,
        );
        final menuBtn = find.byType(PopupMenuButton<String>);
        if (menuBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(menuBtn.first);
          await tester.pumpAndSettle();
          await tester.tap(menuBtn.first);
          await tester.pumpAndSettle();
          final editItem = find.text(S.get('common.edit', loc));
          expect(editItem, findsWidgets);
          await tester.tap(editItem.first);
          await tester.pumpAndSettle();
          expect(find.text(S.get('meds.frequency', loc)), findsWidgets);
          Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
          await tester.pumpAndSettle();
        }
        final refillBtn = find.text(S.get('refill.request', loc));
        if (refillBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(refillBtn.first);
          await tester.pumpAndSettle();
          await tester.tap(refillBtn.first);
          await tester.pumpAndSettle();
          Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('QA [TodayScreen Dark & Skip Sheet] 320x568@1.61 ar & en',
        (tester) async {
      for (final loc in locales) {
        await pumpScreen(
          tester,
          child: const TodayScreen(),
          size: const Size(320, 568),
          locale: loc,
          textScale: 1.61,
          themeMode: ThemeMode.dark,
        );
        final skipBtn = find.byIcon(Icons.skip_next_rounded);
        if (skipBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(skipBtn.first);
          await tester.tap(skipBtn.first);
          await tester.pumpAndSettle();
          Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('QA [Adherence Week Heatmap & Share] 320x568@1.61 ar & en',
        (tester) async {
      for (final loc in locales) {
        await pumpScreen(
          tester,
          child: const AdherenceScreen(),
          size: const Size(320, 568),
          locale: loc,
          textScale: 1.61,
        );
        final weekSeg = find.text(S.get('adherence.week', loc));
        if (weekSeg.evaluate().isNotEmpty) {
          await tester.tap(weekSeg.first);
          await tester.pumpAndSettle();
        }
        final shareBtn = find.byIcon(Icons.ios_share);
        if (shareBtn.evaluate().isNotEmpty) {
          await tester.tap(shareBtn.first);
          await tester.pumpAndSettle();
          Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('QA [CareCircle Invite Sheet] 320x568@1.61 ar & en',
        (tester) async {
      for (final loc in locales) {
        await pumpScreen(
          tester,
          child: const CareCircleScreen(),
          size: const Size(320, 568),
          locale: loc,
          textScale: 1.61,
        );
        final inviteBtn = find.text(S.get('circle.inviteCta', loc));
        if (inviteBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(inviteBtn.first);
          await tester.tap(inviteBtn.first);
          await tester.pumpAndSettle();
          Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('QA [Settings Dark & Modals + ConnectivityBanner] 320x568@1.61 ar & en',
        (tester) async {
      OfflineSyncService.instance.droppedNotifier.value = 2;
      addTearDown(() => OfflineSyncService.instance.droppedNotifier.value = 0);
      for (final loc in locales) {
        await pumpScreen(
          tester,
          child: const SettingsScreen(),
          size: const Size(320, 568),
          locale: loc,
          textScale: 1.61,
          themeMode: ThemeMode.dark,
        );
        final logoutBtn = find.text(S.get('settings.logout', loc));
        if (logoutBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(logoutBtn.first);
          await tester.tap(logoutBtn.first);
          await tester.pumpAndSettle();
          Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      }
    });
  });

  // ---- 3. Populated Caregiver Screens & Tabs ----
  group('Caregiver Regression Matrix', () {
    setUpAll(() async {
      await AuthService().login(
        email: 'caregiver@medimind.app',
        password: 'Pass@123',
      );
    });

    final cgScreens = <(String, Widget Function())>[
      ('CaregiverPatientsScreen', () => const CaregiverPatientsScreen()),
      (
        'PatientDetailScreen',
        () => const PatientDetailScreen(
              patientId: 'patient-1',
              patientName: 'أحمد محمود عبد الرحمن',
              patientPhone: '01012345678',
              emergencyPhone: '01099887766',
            )
      ),
    ];

    for (final (name, builder) in cgScreens) {
      for (final (sizeLabel, size, scale) in configs) {
        for (final locale in locales) {
          testWidgets('QA [$name] $sizeLabel $locale', (tester) async {
            await pumpScreen(
              tester,
              child: builder(),
              size: size,
              locale: locale,
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('QA [PatientDetailScreen Meds Tab & Follow Sheet] 320x568@1.61 ar & en',
        (tester) async {
      for (final loc in locales) {
        await pumpScreen(
          tester,
          child: const PatientDetailScreen(
            patientId: 'patient-1',
            patientName: 'أحمد محمود عبد الرحمن',
            patientPhone: '01012345678',
            emergencyPhone: '01099887766',
          ),
          size: const Size(320, 568),
          locale: loc,
          textScale: 1.61,
        );
        final medsTab = find.textContaining(S.get('cg.tabMeds', loc));
        if (medsTab.evaluate().isNotEmpty) {
          await tester.tap(medsTab.first);
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(tester.takeException(), isNull);
      }
    });
  });
}
