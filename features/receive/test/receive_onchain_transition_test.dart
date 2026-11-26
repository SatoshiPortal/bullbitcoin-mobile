import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive/src/ui/widgets/receive_onchain_transition.dart';

void main() {
  for (final network in [
    BullPaymentNetwork.bitcoin,
    BullPaymentNetwork.liquid,
  ]) {
    for (final confirmed in [false, true]) {
      testWidgets('$network $confirmed exposes back and network', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        var backs = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.dark),
            localizationsDelegates: const [bullUiLocalizationsDelegate],
            home: ReceiveOnchainTransition(
              network: network,
              confirmed: confirmed,
              steps: const ['Payment detected', 'Confirmed'],
              viewDetails: 'View details',
              networkLabel: network == BullPaymentNetwork.bitcoin
                  ? 'Bitcoin'
                  : 'Liquid',
              onBack: () => backs++,
              onViewDetails: () {},
            ),
          ),
        );
        expect(find.byTooltip('Back'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            network == BullPaymentNetwork.bitcoin ? 'Bitcoin' : 'Liquid',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Back'));
        expect(backs, 1);
        semantics.dispose();
      });
    }
  }

  testWidgets('detected transaction offers its details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.dark),
        localizationsDelegates: const [bullUiLocalizationsDelegate],
        home: Builder(
          builder: (context) => ReceiveOnchainTransition(
            network: BullPaymentNetwork.bitcoin,
            confirmed: false,
            steps: const ['Payment detected', 'Confirmed'],
            viewDetails: 'View details',
            networkLabel: 'Bitcoin',
            onBack: () {},
            onViewDetails: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Text('Transaction details'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(BullPaymentTransition), findsOneWidget);
    final transition = tester.widget<BullPaymentTransition>(
      find.byType(BullPaymentTransition),
    );
    expect(transition.progress?.completed, 0);
    expect(transition.direction, BullPaymentDirection.incoming);
    expect(transition.statusTag, 'Payment detected');
    await tester.tap(find.text('View details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Transaction details'), findsOneWidget);
  });
}
