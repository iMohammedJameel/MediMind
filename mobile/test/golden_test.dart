import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/shared/components/components.dart';
import 'package:medimind/shared/network/local/cache_helper.dart';
import 'package:medimind/shared/styles/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Visual regression for the shared design widgets in both themes.
/// Regenerate baselines with: flutter test --update-goldens
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(const {'locale': 'en'});
    await CacheHelper.init();
  });

  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('PatientBottomNav golden — $name', (tester) async {
      tester.view.physicalSize = const Size(1080, 240);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: theme,
        locale: const Locale('en'),
        home: const Scaffold(
          body: SizedBox.expand(),
          bottomNavigationBar: PatientBottomNav(currentIndex: 0),
        ),
      ));
      await expectLater(
        find.byType(PatientBottomNav),
        matchesGoldenFile('goldens/bottom_nav_$name.png'),
      );
    });

    testWidgets('AdherenceRing golden — $name', (tester) async {
      tester.view.physicalSize = const Size(300, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: theme,
        locale: const Locale('en'),
        home: const Scaffold(
          body: Center(child: AdherenceRing(percent: 0.75)),
        ),
      ));
      await expectLater(
        find.byType(AdherenceRing),
        matchesGoldenFile('goldens/adherence_ring_$name.png'),
      );
    });
  }
}
