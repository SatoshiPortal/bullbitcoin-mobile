import 'package:bb_mobile/features/settings/ui/screens/btc_map/btc_map_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'fake_webview_platform.dart';

void main() {
  setUp(() {
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  Widget buildTestWidget() {
    return const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BtcMapScreen(),
    );
  }

  testWidgets('BtcMapScreen renders WebViewWidget', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    expect(find.byType(WebViewWidget), findsOneWidget);
  });

  testWidgets('BtcMapScreen shows loading indicator initially', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    // Before onPageFinished fires, the spinner should be visible
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('BtcMapScreen has a back button', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });
}
