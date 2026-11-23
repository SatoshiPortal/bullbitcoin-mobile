import 'package:wizard/src/ui/wizard_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizard/generated/l10n/wizard_localizations.dart';

import 'test_branding.dart';

/// The wizard builds its own MaterialApp before the main app exists, so it has
/// to compose the store vocabulary itself.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const real =
      'Sovereign self custody Bitcoin wallet and Bitcoin-only exchange service.';
  const apple =
      'Sovereign self custody Bitcoin wallet and Bitcoin-only services.';

  testWidgets('shows the App Store vocabulary on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        WizardApp(
          notificationChannelId: 'payments',
          branding: testBranding,
          exchangeAllowed: false,
          onDone: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(apple), findsOneWidget);
      expect(find.text(real), findsNothing);
      final loc = WizardLocalizations.of(tester.element(find.text(apple)));
      expect(
        loc.wizardJourneyTip5,
        'Transfer between Bitcoin and Liquid with no KYC',
      );
      expect(loc.wizardJourneyTip6, 'Customize your auto transfer settings');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('keeps the real words on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        WizardApp(
          notificationChannelId: 'payments',
          branding: testBranding,
          exchangeAllowed: true,
          onDone: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(real), findsOneWidget);
      expect(find.text(apple), findsNothing);
      final loc = WizardLocalizations.of(tester.element(find.text(real)));
      expect(
        loc.wizardJourneyTip5,
        'Swap between Bitcoin and Liquid with no KYC',
      );
      expect(loc.wizardJourneyTip6, 'Customize your autoswap settings');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
