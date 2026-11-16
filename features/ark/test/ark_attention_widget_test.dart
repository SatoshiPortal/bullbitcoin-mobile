import 'package:ark/ark.dart';
import 'package:bull_ark/ark_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ark_expiry_warning_test.dart' show observed;

void main() {
  testWidgets(
    'funded-off entry remains actionable without native module localization setup',
    (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          home: Scaffold(
            body: ArkAttention(
              snapshot: observed(),
              enabled: false,
              onOpen: () => opened = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final message = find.text(
        'Ark is off for new payments. Existing funds still need renewal and recovery remains available.',
      );
      expect(message, findsOneWidget);
      await tester.tap(message);
      expect(opened, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'delegated renewal remains attention without claiming replacement',
    (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: const [ArkFallbackDelegate()],
          home: Scaffold(
            body: ArkAttention(
              snapshot: observed(renewal: ArkRenewalStatus.delegated),
              enabled: true,
              onOpen: () => opened = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final message = find.text(
        'Renewal started. Your warning stays until replacement VTXOs are observed.',
      );
      expect(message, findsOneWidget);
      await tester.tap(message);
      expect(opened, true);
    },
  );
  test('fallback catalogues preserve French locale variants and serve English otherwise', () async {
    const delegate = ArkFallbackDelegate();
    final french = await delegate.load(const Locale('fr', 'CA'));
    final english = await delegate.load(const Locale('de'));
    expect(french.renewalWarning, contains('renouvel'));
    expect(english.renewalWarning, startsWith('Your VTXOs'));
  });
}
