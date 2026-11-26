import 'package:wizard/src/ui/screens/wizard_screen.dart';
import 'package:wizard/src/ui/widgets/customize_step.dart';
import 'package:wizard/src/ui/wizard_app.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_ui/bull_ui.dart' show BullLoader;
import 'package:flutter/widgets.dart' show Size, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_branding.dart';

/// The wizard offers no exchange choice on any platform: the exchange is only
/// managed from Settings > Exchange. [WizardScreen.exchangeAllowed] still
/// follows the platform, as it gates the default applied on completion.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('hands off exactly once after completion', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var handoffs = 0;
    await tester.pumpWidget(
      WizardApp(
        notificationChannelId: 'payments',
        branding: testBranding,
        exchangeAllowed: true,
        onDone: (_) => handoffs++,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.tap(find.text('Skip'));
    expect(handoffs, 0);
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
    expect(handoffs, 1);
    expect(find.byType(BullLoader), findsOneWidget);
    expect(find.bySemanticsLabel('Preparing your wallet'), findsOneWidget);
    expect(find.text('Skip').hitTestable(), findsNothing);
    expect(find.text('Get started').hitTestable(), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(handoffs, 1);
    await tester.pumpWidget(const SizedBox());
    expect(find.byType(BullLoader), findsNothing);
  });

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
