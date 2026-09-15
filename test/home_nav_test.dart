import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_ahaw/services/localization_service.dart';
import 'package:mobile_ahaw/theme/app_theme.dart';
import 'package:mobile_ahaw/widgets/home/home_nav.dart';

/// The landing nav packs five controls into one row, and one of them is a
/// language label whose width depends on the reader's language — 'Afaan
/// Oromoo' is three times the width of 'አማርኛ'. A row with no flexible child
/// overflows silently in release builds; these pin the widths down instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Both providers read SharedPreferences on construction. Without mock
    // values the platform channel never answers and the test hangs rather
    // than failing.
    SharedPreferences.setMockInitialValues({});
    // Otherwise every notoSansEthiopic() call tries to fetch over HTTP.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget harness(LocalizationService loc) => MultiProvider(
        providers: [
          ChangeNotifierProvider<LocalizationService>.value(value: loc),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: HomeNav(
              scrolled: false,
              activeSection: kHomeSections.first,
              onNavigate: (_) {},
            ),
            body: const SizedBox.expand(),
          ),
        ),
      );

  /// The narrowest phone the congregation is likely to hold, and the most
  /// common Android width.
  const sizes = <String, Size>{
    '320x640': Size(320, 640),
    '360x800': Size(360, 800),
  };

  for (final lang in LocalizationService.supportedLanguages) {
    for (final entry in sizes.entries) {
      testWidgets('nav fits at ${entry.key} in "$lang"', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final loc = LocalizationService();
        // Deliberately not awaited: setLanguage assigns before it touches
        // storage, and awaiting would park on the prefs write.
        loc.setLanguage(lang);

        await tester.pumpWidget(harness(loc));
        await tester.pump();

        // A RenderFlex overflow is reported as an exception, not a failure.
        expect(tester.takeException(), isNull,
            reason: 'nav overflows at ${entry.key} with language "$lang"');
      });
    }
  }

  testWidgets('every control is reachable', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final loc = LocalizationService();
    await tester.pumpWidget(harness(loc));
    await tester.pump();

    // Language, theme, menu and Login — losing any of these to a layout
    // change would strand a reader who scrolled past the hero.
    expect(find.byIcon(Icons.language), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.text(loc.t('nav.login')), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) =>
          w is Icon &&
          (w.icon == Icons.dark_mode || w.icon == Icons.light_mode)),
      findsOneWidget,
    );
  });
}
