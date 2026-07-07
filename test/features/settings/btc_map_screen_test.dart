import 'package:bb_mobile/features/settings/ui/screens/btc_map/btc_map_screen.dart';
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
      // AppLocalizations requires localization delegates; for a minimal test
      // we wrap in MaterialApp which provides basic Material context.
      // Full localization testing requires the generated delegates from
      // flutter gen-l10n which aren't available in CI without a build step.
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
