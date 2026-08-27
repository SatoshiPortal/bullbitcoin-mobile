import 'package:bb_mobile/features/settings/ui/screens/btc_map/btc_map_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'fake_webview_platform.dart';

void main() {
  setUp(() {
    WebViewPlatform.instance = FakeWebViewPlatform();
    FakeWebViewPlatform.lastNavigationDelegate = null;
    FakeWebViewPlatform.lastController = null;
  });

  group('isBtcMapUrl', () {
    test('allows the map url and btcmap.org subdomains over https', () {
      expect(isBtcMapUrl('https://btcmap.org/map'), isTrue);
      expect(isBtcMapUrl('https://btcmap.org'), isTrue);
      expect(isBtcMapUrl('https://api.btcmap.org/v2/elements'), isTrue);
    });

    test('rejects lookalike hosts, downgrades and non-http schemes', () {
      expect(isBtcMapUrl('http://btcmap.org/map'), isFalse);
      expect(isBtcMapUrl('https://evilbtcmap.org'), isFalse);
      expect(isBtcMapUrl('https://btcmap.org.evil.com'), isFalse);
      expect(isBtcMapUrl('javascript:alert(1)'), isFalse);
      expect(isBtcMapUrl(''), isFalse);
    });
  });

  Widget buildTestWidget({Brightness? brightness}) {
    return MaterialApp(
      theme: brightness == null ? null : ThemeData(brightness: brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BtcMapScreen(),
    );
  }

  testWidgets('renders the WebView with a loading indicator initially', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    expect(find.byType(WebViewWidget), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'primes localStorage theme to dark and reloads when the app is dark',
    (tester) async {
      await tester.pumpWidget(buildTestWidget(brightness: Brightness.dark));
      await tester.pump();

      final controller = FakeWebViewPlatform.lastController!;
      // Nothing primed until the first page load reports finished.
      expect(controller.ranJavaScript, isEmpty);
      expect(controller.reloadCount, 0);

      FakeWebViewPlatform.lastNavigationDelegate!.pageFinishedCallback!(
        'https://btcmap.org/map',
      );
      // Two pumps flush the async prime (runJavaScript then reload) and the
      // rebuild; pumpAndSettle can't be used while the spinner animates.
      await tester.pump();
      await tester.pump();

      expect(controller.ranJavaScript.single, contains("localStorage.theme"));
      expect(controller.ranJavaScript.single, contains("'dark'"));
      // The basemap is pinned to OpenFreeMap Dark, not left to btcmap's
      // theme-derived default (which can pick the light basemap for a dark app).
      expect(controller.ranJavaScript.single, contains("btcmap-next-basemap"));
      expect(controller.ranJavaScript.single, contains("ofm-dark"));
      expect(controller.reloadCount, 1);
      // The reload keeps the loading overlay up until its own page-finished.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // The reloaded page finishing clears the overlay and does not re-prime.
      FakeWebViewPlatform.lastNavigationDelegate!.pageFinishedCallback!(
        'https://btcmap.org/map',
      );
      await tester.pump();

      expect(controller.ranJavaScript.length, 1);
      expect(controller.reloadCount, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('re-primes and reloads when the app theme changes while open', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(brightness: Brightness.dark));
    await tester.pump();

    final controller = FakeWebViewPlatform.lastController!;
    // Initial load primes dark and reloads once.
    FakeWebViewPlatform.lastNavigationDelegate!.pageFinishedCallback!(
      'https://btcmap.org/map',
    );
    await tester.pump();
    await tester.pump();
    // The reload's own page-finished clears the initial-load overlay.
    FakeWebViewPlatform.lastNavigationDelegate!.pageFinishedCallback!(
      'https://btcmap.org/map',
    );
    await tester.pump();
    expect(controller.ranJavaScript.single, contains("'dark'"));
    expect(controller.reloadCount, 1);

    // App theme flips to light while the screen stays mounted: the same
    // controller must be re-primed to light and reloaded again. Pump past the
    // MaterialApp AnimatedTheme (~200ms) so the resolved brightness crosses to
    // light, then flush the async re-prime.
    await tester.pumpWidget(buildTestWidget(brightness: Brightness.light));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(controller.ranJavaScript.length, 2);
    expect(controller.ranJavaScript.last, contains("'light'"));
    expect(controller.ranJavaScript.last, contains("liberty"));
    expect(controller.reloadCount, 2);
  });

  testWidgets('primes localStorage theme to light when the app is light', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(brightness: Brightness.light));
    await tester.pump();

    FakeWebViewPlatform.lastNavigationDelegate!.pageFinishedCallback!(
      'https://btcmap.org/map',
    );
    await tester.pump();
    await tester.pump();

    final controller = FakeWebViewPlatform.lastController!;
    expect(controller.ranJavaScript.single, contains("'light'"));
    expect(controller.ranJavaScript.single, contains("liberty"));
    expect(controller.reloadCount, 1);
  });

  testWidgets('shows an error state with retry on main-frame load failure', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    final delegate = FakeWebViewPlatform.lastNavigationDelegate;
    expect(delegate?.webResourceErrorCallback, isNotNull);
    delegate!.webResourceErrorCallback!(
      WebResourceError(
        errorCode: -2,
        description: 'net::ERR_INTERNET_DISCONNECTED',
        isForMainFrame: true,
      ),
    );
    await tester.pump();

    expect(find.byType(WebViewWidget), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(find.byType(WebViewWidget), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ignores subresource errors', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    FakeWebViewPlatform.lastNavigationDelegate!.webResourceErrorCallback!(
      WebResourceError(
        errorCode: -2,
        description: 'one tile failed',
        isForMainFrame: false,
      ),
    );
    await tester.pump();

    expect(find.byType(WebViewWidget), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('back button pops the screen when the webview has no history', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const BtcMapScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    // The pop is async (canGoBack first): settle through the microtask and
    // the reverse route transition. Settles because the home route animates
    // nothing once BtcMapScreen (and its spinner) is gone.
    await tester.pumpAndSettle();

    expect(find.byType(BtcMapScreen), findsNothing);
  });
}
