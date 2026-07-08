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

  Widget buildTestWidget() {
    return const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BtcMapScreen(),
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
