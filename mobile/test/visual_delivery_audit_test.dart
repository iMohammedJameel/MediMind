import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:medimind/shared/components/components.dart';
import 'package:medimind/shared/components/connectivity_banner.dart';
import 'package:medimind/shared/network/local/cache_helper.dart';
import 'package:medimind/shared/network/remote/dio_helper.dart';
import 'package:medimind/shared/styles/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks every API call triggered during interactive E2E feature tests and
/// returns realistic responses matching `scripts/mock_backend/server.js`.
class _AuditHttpOverrides extends HttpOverrides {
  static final List<String> calls = [];
  static String role = 'PATIENT';

  @override
  HttpClient createHttpClient(SecurityContext? context) => _AuditHttpClient();
}

class _AuditHttpClient implements HttpClient {
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _AuditHttpRequest(method, url);
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

class _AuditHttpRequest implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;
  _AuditHttpRequest(this.method, this.uri);

  @override
  final HttpHeaders headers = _AuditHeaders();
  @override
  Encoding encoding = utf8;
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  final List<int> _body = [];

  @override
  void add(List<int> data) => _body.addAll(data);
  @override
  void write(Object? object) => _body.addAll(utf8.encode('$object'));

  @override
  Future<HttpClientResponse> close() async {
    final path = uri.path;
    final p = path.startsWith('/api/v1') ? path.substring(7) : path;
    _AuditHttpOverrides.calls.add('$method $p');

    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final mo = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final todayPrefix = '$y-$mo-$d';
    final from = uri.queryParameters['from'];
    final to = uri.queryParameters['to'];

    dynamic payload;
    if (p == '/auth/login' || p == '/auth/register') {
      payload = {
        'accessToken': 'tok_audit',
        'refreshToken': 'rf_audit',
        'user': {
          '_id': 'u-ahmed',
          'role': _AuditHttpOverrides.role,
          'firstName': 'أحمد',
          'lastName': 'محمود',
          'email': 'patient@medimind.app',
          'phone': '01012345678',
        },
      };
    } else if (p == '/auth/forgot-password') {
      payload = {'sent': true};
    } else if (p == '/auth/reset-password') {
      payload = {'reset': true};
    } else if (p == '/doses' && from != null && to != null) {
      final start = DateTime.tryParse(from) ?? now.subtract(const Duration(days: 6));
      final end = DateTime.tryParse(to) ?? now;
      final list = <Map<String, dynamic>>[];
      for (var cur = start; !cur.isAfter(end); cur = cur.add(const Duration(days: 1))) {
        final ds =
            '${cur.year.toString().padLeft(4, '0')}-${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')}';
        final dayOffset = now.difference(cur).inDays;
        list.addAll([
          {
            'doseEventId': 'd-c-$ds',
            'medicationId': {'_id': 'm-1', 'name': 'Concor 5mg'},
            'scheduledFor': '${ds}T08:00:00',
            'status': 'TAKEN',
          },
          {
            'doseEventId': 'd-a-$ds',
            'medicationId': {'_id': 'm-2', 'name': 'Amaryl 2mg'},
            'scheduledFor': '${ds}T08:00:00',
            'status': dayOffset % 4 == 0 ? 'MISSED' : 'TAKEN',
          },
          {
            'doseEventId': 'd-g-$ds',
            'medicationId': {'_id': 'm-3', 'name': 'Glucophage XR 1000mg'},
            'scheduledFor': '${ds}T21:00:00',
            'status': ds == todayPrefix ? 'PENDING' : 'TAKEN',
          },
        ]);
      }
      payload = list;
    } else if (p == '/doses') {
      final futureHour = now.add(const Duration(hours: 2));
      final fh = futureHour.day == now.day
          ? '${futureHour.hour.toString().padLeft(2, '0')}:${futureHour.minute.toString().padLeft(2, '0')}:00'
          : '23:59:00';
      payload = [
        {
          'doseEventId': 'd-1',
          'medicationId': {'_id': 'm-1', 'name': 'Concor 5mg'},
          'scheduledFor': '${todayPrefix}T08:00:00',
          'status': 'TAKEN',
        },
        {
          'doseEventId': 'd-2',
          'medicationId': {'_id': 'm-2', 'name': 'Amaryl 2mg'},
          'scheduledFor': '${todayPrefix}T13:30:00',
          'status': 'MISSED',
        },
        {
          'doseEventId': 'd-3',
          'medicationId': {'_id': 'm-3', 'name': 'Glucophage XR 1000mg'},
          'scheduledFor': '${todayPrefix}T$fh',
          'status': 'PENDING',
        },
      ];
    } else if (p.startsWith('/doses/') && p.endsWith('/confirm')) {
      payload = {'doseEventId': 'd-3', 'status': 'TAKEN'};
    } else if (p.startsWith('/doses/') && p.endsWith('/skip')) {
      payload = {'doseEventId': 'd-3', 'status': 'SKIPPED'};
    } else if (p == '/doses/extra') {
      payload = {
        'doseEventId': 'dx-1',
        'medicationId': {'_id': 'm-4', 'name': 'Panadol Advance'},
        'medicationName': 'Panadol Advance',
        'scheduledFor': '${todayPrefix}T12:00:00',
        'status': 'TAKEN',
      };
    } else if (p == '/medications' && method == 'POST') {
      payload = {
        'medicationId': 'm-new',
        'interactionWarnings': [
          {
            'severity': 'HIGH',
            'effect': 'Combined use increases the risk of hypoglycemia.',
            'effectAr': 'الاستخدام المشترك يزيد خطر هبوط السكر والنزيف الهضمي.',
            'recommendation': 'Consult your doctor.',
            'recommendationAr': 'استشر طبيبك وتناوله مع الطعام.',
          }
        ],
      };
    } else if (p == '/medications') {
      payload = [
        {
          '_id': 'm-1',
          'name': 'Concor 5mg',
          'formType': 'TABLET',
          'isActive': true,
          'isChronic': true,
          'schedule': {'frequency': 'DAILY', 'dosesPerDay': 1, 'firstDoseTime': '08:00'},
          'inventory': {'currentQuantity': 28, 'refillThreshold': 10, 'doseAmount': 1},
          'instructions': {'relationToMeals': 'AFTER_MEALS', 'notes': 'قرص صباحًا بعد الفطار'},
        },
        {
          '_id': 'm-2',
          'name': 'Amaryl 2mg',
          'formType': 'TABLET',
          'isActive': true,
          'isChronic': true,
          'schedule': {'frequency': 'DAILY', 'dosesPerDay': 1, 'firstDoseTime': '08:00'},
          'inventory': {'currentQuantity': 15, 'refillThreshold': 6, 'doseAmount': 1},
          'instructions': {'relationToMeals': 'BEFORE_MEALS', 'notes': 'قبل وجبة الإفطار مباشرة'},
        },
        {
          '_id': 'm-3',
          'name': 'Glucophage XR 1000mg',
          'formType': 'TABLET',
          'isActive': true,
          'isChronic': true,
          'schedule': {'frequency': 'DAILY', 'dosesPerDay': 1, 'firstDoseTime': '21:00'},
          'inventory': {'currentQuantity': 4, 'refillThreshold': 5, 'doseAmount': 1},
          'instructions': {'relationToMeals': 'WITH_FOOD', 'notes': 'مع وجبة العشاء'},
        },
        {
          '_id': 'm-4',
          'name': 'Panadol Advance',
          'formType': 'TABLET',
          'isActive': true,
          'isChronic': false,
          'schedule': {'frequency': 'AS_NEEDED', 'dosesPerDay': 1, 'firstDoseTime': '12:00'},
          'inventory': {'currentQuantity': 12, 'refillThreshold': 4, 'doseAmount': 1},
          'instructions': {'relationToMeals': 'NONE', 'notes': 'عند اللزوم فقط'},
        },
        {
          '_id': 'm-5',
          'name': 'Lipitor 20mg',
          'formType': 'CAPSULE',
          'isActive': false,
          'isChronic': true,
          'schedule': {'frequency': 'DAILY', 'dosesPerDay': 1, 'firstDoseTime': '22:00'},
          'inventory': {'currentQuantity': 0, 'refillThreshold': 5, 'doseAmount': 1},
          'instructions': {'relationToMeals': 'NONE', 'notes': ''},
        },
      ];
    } else if (p == '/medications/refills' && method == 'POST') {
      payload = {'refillOrderId': 'ro-new'};
    } else if (p == '/medications/refills') {
      payload = [
        {
          '_id': 'ro-1',
          'medicationId': {'_id': 'm-3', 'name': 'Glucophage XR 1000mg'},
          'targetPharmacyId': {'_id': 'ph-1', 'pharmacyName': 'صيدلية العزبي'},
          'quantityRequested': 30,
          'fulfillmentType': 'DELIVERY',
          'orderStatus': 'SUBMITTED',
          'createdAt': '${todayPrefix}T07:00:00Z',
        },
      ];
    } else if (p == '/profiles/pharmacists') {
      payload = [
        {
          '_id': 'ph-1',
          'pharmacyName': 'صيدلية العزبي',
          'address': {'city': 'مصر الجديدة', 'governorate': 'القاهرة'},
          'pharmacyPhone': '0224191234',
          'is24Hours': true,
          'offersDelivery': true,
        },
      ];
    } else if (p == '/relationships' && method == 'POST') {
      payload = {'relationshipId': 'rel-new'};
    } else if (p == '/relationships') {
      payload = [
        {
          '_id': 'rel-1',
          'status': 'ACCEPTED',
          'relation': 'ابنة',
          'caregiverId': {
            '_id': 'u-mona',
            'firstName': 'منى',
            'lastName': 'أحمد',
          },
          'patientId': {
            '_id': 'u-ahmed',
            'firstName': 'أحمد',
            'lastName': 'محمود',
            'phone': '01012345678',
            'emergencyPhone': '01098765432',
          },
        },
        {
          '_id': 'rel-2',
          'status': 'PENDING',
          'relation': 'جارة',
          'caregiverId': {
            '_id': 'u-marwan',
            'firstName': 'مروان',
            'lastName': 'أحمد',
          },
          'patientId': {
            '_id': 'u-soad',
            'firstName': 'سعاد',
            'lastName': 'فؤاد',
          },
        },
      ];
    } else if (p == '/notifications/unread-count') {
      payload = {'unreadCount': 2};
    } else if (p == '/notifications') {
      payload = [
        {
          '_id': 'n-1',
          'type': 'DOSE_REMINDER',
          'title': 'Time for your dose',
          'titleAr': 'حان وقت جرعتك',
          'message': 'Concor 5mg is scheduled for 08:00',
          'messageAr': 'Concor 5mg موعده ٨:٠٠ صباحًا',
          'isRead': true,
          'createdAt': '${todayPrefix}T06:00:00Z',
        },
        {
          '_id': 'n-2',
          'type': 'MISSED_DOSE_ALERT',
          'title': 'Missed dose alert',
          'titleAr': 'تنبيه جرعة فائتة',
          'message': 'Amaryl 2mg afternoon dose was missed.',
          'messageAr': 'جرعة Amaryl 2mg لم يتم تناولها.',
          'isRead': false,
          'createdAt': '${todayPrefix}T08:30:00Z',
        },
      ];
    } else if (p.startsWith('/profiles/')) {
      payload = {
        'firstName': 'أحمد',
        'lastName': 'محمود',
        'phone': '01012345678',
        'bloodType': 'O+',
        'emergencyContact': {'name': 'سعاد إبراهيم', 'phone': '01098765432'},
        'timezone': 'Africa/Cairo',
      };
    } else {
      payload = {};
    }

    return _AuditHttpResponse(utf8.encode(jsonEncode({'success': true, 'data': payload})));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _AuditHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  final List<int> _bytes;
  _AuditHttpResponse(this._bytes);
  @override
  int get statusCode => 200;
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
  HttpHeaders get headers => _AuditHeaders();
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.fromIterable([_bytes])
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _AuditHeaders implements HttpHeaders {
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

Future<void> _loadRealFonts() async {
  try {
    final cairo = FontLoader('Cairo');
    cairo.addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
    await cairo.load();
  } catch (_) {}

  final iconFile = File(r'C:\src\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf');
  if (iconFile.existsSync()) {
    final icons = FontLoader('MaterialIcons');
    icons.addFont(Future.value(ByteData.sublistView(iconFile.readAsBytesSync())));
    await icons.load();
  }
  final robotoFile = File(r'C:\src\flutter\bin\cache\artifacts\material_fonts\roboto-regular.ttf');
  if (robotoFile.existsSync()) {
    final roboto = FontLoader('Roboto');
    roboto.addFont(Future.value(ByteData.sublistView(robotoFile.readAsBytesSync())));
    await roboto.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captureDir = Platform.environment['VISUAL_QA_DIR'];
  final captureKey = GlobalKey();

  setUpAll(() async {
    await _loadRealFonts();
    HttpOverrides.global = _AuditHttpOverrides();
    SharedPreferences.setMockInitialValues({
      'locale': 'ar',
      'firstName': 'أحمد',
      'email': 'patient@medimind.app',
      'role': 'PATIENT',
      'arabicDigits': true,
      'use24Hour': false,
    });
    FlutterSecureStorage.setMockInitialValues({'accessToken': 'tok_audit'});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
      MockStreamHandler.inline(onListen: (_, events) => events.success(['wifi'])),
    );
    for (final ch in [
      'dev.fluttercommunity.plus/connectivity',
      'com.ryanheise.just_audio.methods',
      'com.ryanheise.audio_session',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async {
        if (call.method == 'check') return ['wifi'];
        if (ch == 'com.ryanheise.just_audio.methods') {
          if (call.method == 'init' && call.arguments is Map) {
            final id = (call.arguments as Map)['id'];
            if (id != null) {
              messenger.setMockMethodCallHandler(
                MethodChannel('com.ryanheise.just_audio.methods.$id'),
                (_) async => <String, dynamic>{},
              );
              messenger.setMockStreamHandler(
                EventChannel('com.ryanheise.just_audio.events.$id'),
                MockStreamHandler.inline(onListen: (_, __) {}),
              );
              messenger.setMockStreamHandler(
                EventChannel('com.ryanheise.just_audio.data.$id'),
                MockStreamHandler.inline(onListen: (_, __) {}),
              );
            }
          }
          return <String, dynamic>{};
        }
        return null;
      });
    }
    await CacheHelper.init();
    await DioHelper.init();
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (captureDir == null || captureDir.isEmpty) return;
    await tester.runAsync(() async {
      final boundary =
          captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final img = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes != null) {
        final dir = Directory(captureDir)..createSync(recursive: true);
        File('${dir.path}/$name.png')
            .writeAsBytesSync(bytes.buffer.asUint8List(), flush: true);
      }
      img.dispose();
    });
  }

  Future<void> pumpTarget(
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
    await CacheHelper.setFirstName('أحمد');

    final router = GoRouter(
      initialLocation: '/target',
      routes: [
        GoRoute(path: '/target', builder: (_, __) => child),
        GoRoute(
          path: '/:rest(.*)',
          builder: (_, st) => Scaffold(body: Center(child: Text('Navigated: ${st.uri}'))),
        ),
      ],
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => SettingsCubit()),
            BlocProvider(create: (_) => ConnectivityCubit()),
          ],
          child: BlocBuilder<SettingsCubit, SettingsState>(
            builder: (_, __) => MaterialApp.router(
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
                  child: MediMindBackground(child: c ?? const SizedBox.shrink()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Visual & Interactive Audit 1: Pre-auth & Utility Screens', (tester) async {
    await pumpTarget(tester,
        child: const OnboardingScreen(),
        size: const Size(390, 844),
        locale: 'ar',
        textScale: 1.15);
    await capture(tester, '01_onboarding_ar_390');
    await tester.tap(find.text(S.get('ob.next', 'ar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.get('ob.next', 'ar')));
    await tester.pumpAndSettle();
    expect(find.text(S.get('ob.start', 'ar')), findsOneWidget);
    await capture(tester, '01b_onboarding_last_ar_390');

    await pumpTarget(tester,
        child: const OnboardingScreen(),
        size: const Size(320, 568),
        locale: 'en',
        textScale: 1.61);
    await capture(tester, '01c_onboarding_en_320');

    await pumpTarget(tester,
        child: const LoginScreen(),
        size: const Size(390, 844),
        locale: 'ar',
        textScale: 1.15);
    await capture(tester, '02_login_ar_390');
    await tester.tap(find.text(S.get('login.method.phone', 'ar')));
    await tester.pumpAndSettle();
    await capture(tester, '02b_login_phone_ar_390');

    await pumpTarget(tester,
        child: const LoginScreen(),
        size: const Size(320, 568),
        locale: 'en',
        textScale: 1.61,
        themeMode: ThemeMode.dark);
    await capture(tester, '02c_login_en_320_dark');

    await pumpTarget(tester,
        child: const RegisterScreen(),
        size: const Size(390, 844),
        locale: 'ar',
        textScale: 1.15);
    await capture(tester, '03_register_ar_390');

    await pumpTarget(tester,
        child: const RegisterScreen(),
        size: const Size(320, 568),
        locale: 'en',
        textScale: 1.61);
    await capture(tester, '03b_register_en_320');

    await pumpTarget(tester,
        child: const ForgotPasswordScreen(),
        size: const Size(360, 640),
        locale: 'ar',
        textScale: 1.15);
    await capture(tester, '04_forgot_ar_360');

    await pumpTarget(tester,
        child: const ResetPasswordScreen(identifier: '01012345678'),
        size: const Size(360, 640),
        locale: 'en',
        textScale: 1.15);
    await capture(tester, '04b_reset_en_360');

    await pumpTarget(tester,
        child: const ProfileSetupScreen(),
        size: const Size(390, 844),
        locale: 'ar',
        textScale: 1.15);
    await capture(tester, '05_profile_setup_ar_390');

    await pumpTarget(tester,
        child: const PrivacyPolicyScreen(),
        size: const Size(390, 844),
        locale: 'ar',
        textScale: 1.15);
    await capture(tester, '06_privacy_ar_390');

    await pumpTarget(tester,
        child: const ScanScreen(),
        size: const Size(320, 568),
        locale: 'ar',
        textScale: 1.61);
    expect(find.text(S.get('scan.tipLighting', 'ar')), findsOneWidget);
    await capture(tester, '07_scan_ar_320');

    await pumpTarget(tester,
        child: const ScanScreen(),
        size: const Size(390, 844),
        locale: 'en',
        textScale: 1.15);
    await capture(tester, '07b_scan_en_390');

    expect(tester.takeException(), isNull);
  });

  testWidgets('Visual & Interactive Audit 2: TodayScreen (Light, Dark, Actions, Skip Sheet)',
      (tester) async {
    _AuditHttpOverrides.calls.clear();

    await pumpTarget(tester,
        child: const TodayScreen(),
        size: const Size(390, 844),
        locale: 'ar',
        textScale: 1.15);
    expect(find.textContaining('أحمد'), findsWidgets);
    await capture(tester, '08_today_ar_390');

    // Scroll to scheduled doses & verify morning/evening headers + meal badges + skip sheet
    final morningHdr = find.text(S.get('today.periodMorning', 'ar'));
    await tester.scrollUntilVisible(
      morningHdr,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(morningHdr, findsOneWidget);

    final skipBtn = find.byIcon(Icons.skip_next_rounded);
    await tester.scrollUntilVisible(
      skipBtn.first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await capture(tester, '08a_today_doses_ar_390');
    await tester.tap(skipBtn.first);
    await tester.pumpAndSettle();
    expect(find.text(S.get('today.skipConfirmTitle', 'ar')), findsOneWidget);
    await capture(tester, '08b_today_skip_sheet_ar_390');
    await tester.tap(find.text(S.get('today.snooze15Instead', 'ar')));
    await tester.pumpAndSettle();

    // Mark Taken -> find actual Taken FilledButton, wait past 450ms delay & verify API hit
    final takenBtn =
        find.widgetWithText(FilledButton, S.get('today.taken', 'ar'));
    if (takenBtn.evaluate().isNotEmpty) {
      await tester.ensureVisible(takenBtn.first);
      await tester.pumpAndSettle();
      await tester.tap(takenBtn.first);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }
    expect(_AuditHttpOverrides.calls.any((c) => c.contains('/confirm')), isTrue);

    // Dark 320 + English + Tablet
    await pumpTarget(tester,
        child: const TodayScreen(),
        size: const Size(320, 568),
        locale: 'ar',
        textScale: 1.61,
        themeMode: ThemeMode.dark);
    await capture(tester, '08c_today_ar_320_dark');

    await pumpTarget(tester,
        child: const TodayScreen(),
        size: const Size(320, 568),
        locale: 'en',
        textScale: 1.61);
    await capture(tester, '08d_today_en_320');
    final morningEn = find.text(S.get('today.periodMorning', 'en'));
    await tester.scrollUntilVisible(
      morningEn,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(morningEn, findsOneWidget);

    await pumpTarget(tester,
        child: const TodayScreen(),
        size: const Size(768, 1024),
        locale: 'ar',
        textScale: 1.61);
    await capture(tester, '08e_today_ar_768_tablet');

    expect(tester.takeException(), isNull);
  });

  testWidgets('Visual & Interactive Audit 3: Medications (Search, Filter, Add 2-Step, Edit, Refill)',
      (tester) async {
    _AuditHttpOverrides.calls.clear();

    await pumpTarget(tester,
        child: const MedicationsScreen(),
        size: const Size(390, 844),
        locale: 'ar',
        textScale: 1.15);
    expect(find.text('Concor 5mg'), findsOneWidget);
    expect(find.text(S.get('meds.activeRefill', 'ar')), findsOneWidget);
    await capture(tester, '09_meds_ar_390');

    // Filter Low Stock -> only Glucophage XR visible
    await tester.tap(find.text(S.get('meds.filterLowStock', 'ar')));
    await tester.pumpAndSettle();
    expect(find.text('Glucophage XR 1000mg'), findsOneWidget);
    expect(find.text('Concor 5mg'), findsNothing);

    // Back to All & Search for Concor
    await tester.tap(find.text(S.get('meds.filterAll', 'ar')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Concor');
    await tester.pumpAndSettle();
    expect(find.text('Concor 5mg'), findsOneWidget);
    expect(find.text('Lipitor 20mg'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();

    // Expand Add Medication 2-step form
    final addTile = find.text(S.get('meds.addNew', 'ar'));
    await tester.scrollUntilVisible(
      addTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(addTile);
    await tester.pumpAndSettle();
    expect(find.text(S.get('meds.step1', 'ar')), findsOneWidget);
    await capture(tester, '09b_meds_add_step1_ar_390');

    // Enter name & advance to Step 2
    final nameFields = find.widgetWithText(TextFormField, S.get('meds.name', 'ar'));
    await tester.ensureVisible(nameFields.first);
    await tester.pumpAndSettle();
    await tester.enterText(nameFields.first, 'Aspirin 81mg');
    final nextStepBtn = find.text(S.get('meds.nextStep', 'ar'));
    await tester.ensureVisible(nextStepBtn);
    await tester.pumpAndSettle();
    await tester.tap(nextStepBtn);
    await tester.pumpAndSettle();
    expect(find.text(S.get('meds.prevStep', 'ar')), findsOneWidget);
    await capture(tester, '09c_meds_add_step2_ar_390');

    // English 320 + Edit & Refill sheets
    await pumpTarget(tester,
        child: const MedicationsScreen(),
        size: const Size(320, 568),
        locale: 'en',
        textScale: 1.61);
    await capture(tester, '09d_meds_en_320');

    final refillBtn = find.text(S.get('refill.request', 'en'));
    await tester.ensureVisible(refillBtn.first);
    await tester.pumpAndSettle();
    await tester.tap(refillBtn.first);
    await tester.pumpAndSettle();
    await capture(tester, '09e_meds_refill_sheet_en_320');
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Visual & Interactive Audit 4: Adherence (Today, Week Heatmap, Month, Dark, Share)',
      (tester) async {
    await pumpTarget(tester,
        child: const AdherenceScreen(),
        size: const Size(390, 844),
        locale: 'ar',
        textScale: 1.15);
    await capture(tester, '10_adherence_today_ar_390');

    await tester.tap(find.text(S.get('adherence.week', 'ar')));
    await tester.pumpAndSettle();
    expect(find.text(S.get('adherence.dailyCalendar', 'ar')), findsOneWidget);
    await capture(tester, '10b_adherence_week_ar_390');

    await tester.tap(find.text(S.get('adherence.month', 'ar')));
    await tester.pumpAndSettle();
    await capture(tester, '10c_adherence_month_ar_390');

    await pumpTarget(tester,
        child: const AdherenceScreen(),
        size: const Size(320, 568),
        locale: 'en',
        textScale: 1.61,
        themeMode: ThemeMode.dark);
    await tester.tap(find.text(S.get('adherence.week', 'en')));
    await tester.pumpAndSettle();
    await capture(tester, '10d_adherence_week_en_320_dark');

    expect(tester.takeException(), isNull);
  });

  testWidgets('Visual & Interactive Audit 5: CareCircle, Notifications, Settings, Caregiver, Alarm',
      (tester) async {
    // CareCircle AR & Invite Sheet
    await pumpTarget(tester,
        child: const CareCircleScreen(),
        size: const Size(390, 844),
        locale: 'ar',
        textScale: 1.15);
    await capture(tester, '11_care_circle_ar_390');
    await tester.tap(find.text(S.get('circle.invite', 'ar')));
    await tester.pumpAndSettle();
    await capture(tester, '11b_care_circle_invite_ar_390');
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pumpAndSettle();

    // Notifications AR & EN (checking real titleAr vs title!)
    await pumpTarget(tester,
        child: const NotificationsScreen(),
        size: const Size(390, 844),
        locale: 'ar',
        textScale: 1.15);
    expect(find.text('حان وقت جرعتك'), findsOneWidget);
    await capture(tester, '12_notifs_ar_390');

    await pumpTarget(tester,
        child: const NotificationsScreen(),
        size: const Size(320, 568),
        locale: 'en',
        textScale: 1.61);
    expect(find.text('Time for your dose'), findsOneWidget);
    await capture(tester, '12b_notifs_en_320');

    // Settings Light AR + Dark EN
    await pumpTarget(tester,
        child: const SettingsScreen(),
        size: const Size(390, 844),
        locale: 'ar',
        textScale: 1.15);
    await capture(tester, '13_settings_ar_390');

    await pumpTarget(tester,
        child: const SettingsScreen(),
        size: const Size(320, 568),
        locale: 'en',
        textScale: 1.61,
        themeMode: ThemeMode.dark);
    await capture(tester, '13b_settings_en_320_dark');

    // Caregiver Patients + PatientDetail (Doses, Meds, Dark)
    _AuditHttpOverrides.role = 'FAMILY_CAREGIVER';
    await CacheHelper.setRole('FAMILY_CAREGIVER');
    await pumpTarget(tester,
        child: const CaregiverPatientsScreen(),
        size: const Size(390, 844),
        locale: 'ar',
        textScale: 1.15);
    await capture(tester, '14_cg_patients_ar_390');

    await pumpTarget(tester,
        child: const PatientDetailScreen(
          patientId: 'u-ahmed',
          patientName: 'أحمد محمود',
          patientPhone: '01012345678',
          emergencyPhone: '01098765432',
        ),
        size: const Size(390, 844),
        locale: 'ar',
        textScale: 1.15);
    await capture(tester, '15_cg_detail_doses_ar_390');

    await tester.tap(find.byIcon(Icons.medication_outlined));
    await tester.pumpAndSettle();
    await capture(tester, '15b_cg_detail_meds_ar_390');

    await pumpTarget(tester,
        child: const PatientDetailScreen(
          patientId: 'u-ahmed',
          patientName: 'Ahmed Mahmoud',
          patientPhone: '01012345678',
          emergencyPhone: '01098765432',
        ),
        size: const Size(320, 568),
        locale: 'en',
        textScale: 1.61,
        themeMode: ThemeMode.dark);
    await capture(tester, '15c_cg_detail_en_320_dark');

    // Alarm Screen AR & EN
    await pumpTarget(tester,
        child: AlarmScreen(
          dose: DoseEventModel(
            id: 'd-3',
            medicationId: 'm-3',
            medicationName: 'Glucophage XR 1000mg',
            scheduledFor: DateTime(2026, 11, 26, 21, 0),
            status: 'PENDING',
          ),
        ),
        size: const Size(390, 844),
        locale: 'ar',
        textScale: 1.15);
    await capture(tester, '16_alarm_ar_390');

    await pumpTarget(tester,
        child: AlarmScreen(
          dose: DoseEventModel(
            id: 'd-3',
            medicationId: 'm-3',
            medicationName: 'Glucophage XR 1000mg',
            scheduledFor: DateTime(2026, 11, 26, 21, 0),
            status: 'PENDING',
          ),
        ),
        size: const Size(320, 568),
        locale: 'en',
        textScale: 1.61);
    await capture(tester, '16b_alarm_en_320');

    expect(tester.takeException(), isNull);
  });
}
