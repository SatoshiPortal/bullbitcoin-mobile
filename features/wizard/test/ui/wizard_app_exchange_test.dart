import 'package:wizard/src/ui/screens/wizard_screen.dart';
import 'package:wizard/src/ui/widgets/customize_step.dart';
import 'package:wizard/src/ui/wizard_app.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_branding.dart';

/// The wizard offers no exchange choice on any platform: the exchange is only
/// managed from Settings > Exchange. [WizardScreen.exchangeAllowed] still
/// follows the platform, as it gates the default applied on completion.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (platform, allowed) in [
    (ExchangePlatform.ios, false),
    (ExchangePlatform.other, true),
  ]) {
    testWidgets('shows no exchange row on ${platform.name}', (tester) async {
      await tester.pumpWidget(
        WizardApp(
          notificationChannelId: 'payments',
          branding: testBranding,
          exchangeAllowed: ExchangeAvailability.platformAllowed(platform),
          onDone: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      final screen = tester.widget<WizardScreen>(find.byType(WizardScreen));
      expect(screen.exchangeAllowed, allowed);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomizeStep), findsOneWidget);
      expect(find.text('BULL Exchange'), findsNothing);
    });
  }
}
