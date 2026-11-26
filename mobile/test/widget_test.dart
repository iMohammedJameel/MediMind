import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/shared/network/local/cache_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medimind/modules/alarm/alarm_screen.dart';
import 'package:medimind/models/dose_event_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    await CacheHelper.init();
  });

  final dose = DoseEventModel(
    id: 'dose-1',
    medicationId: 'med-1',
    medicationName: 'أملوديبين 5mg',
    scheduledFor: DateTime(2026, 8, 21, 8, 0),
    status: 'PENDING',
  );

  testWidgets('Alarm screen shows medication name and actions',
      (WidgetTester tester) async {
    // Mirrors the real app wiring: MaterialApp always receives the cached
    // locale + supportedLocales (main.dart). Without supportedLocales the
    // locale resolution falls back to en_US and tr() renders English.
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AlarmScreen(dose: dose),
    ));

    // NOT pumpAndSettle: the pulsing medication icon repeats forever, so
    // settling would time out. A fixed pump advances one frame instead.
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('أملوديبين 5mg'), findsOneWidget);
    expect(find.text('تم التناول'), findsOneWidget);
    expect(find.text('تذكيرني بعد ٥ دقائق'), findsOneWidget);
    expect(find.text('تجاوز الجرعة'), findsOneWidget);
  });
}
