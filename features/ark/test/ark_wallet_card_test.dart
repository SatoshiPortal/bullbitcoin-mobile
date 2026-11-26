import 'package:ark/ark.dart';
import 'package:bull_ark/ark_ui.dart' show ArkWalletCard;
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_operations_test.dart' show account;

void main() {
  for (final ready in [false, true]) {
    for (final hidden in [false, true]) {
      testWidgets(
        'dashboard amount respects preferences ready=$ready hidden=$hidden',
        (tester) async {
          var opened = 0;
          final snapshot = ArkSnapshot(
            account: account(),
            revision: 1,
            observedAt: DateTime.utc(2026, 11, 18),
            stale: false,
            spendable: Sats.fromInt(1234),
          );
          await tester.pumpWidget(
            app(
              BullAmountScope(
                snapshot: BullAmountSnapshot(
                  unit: BitcoinUnit.sats,
                  hideAmounts: hidden,
                  isReady: ready,
                ),
                writeUnit: (_) async => false,
                child: ArkWalletCard(
                  snapshot: snapshot,
                  onOpen: () => opened++,
                ),
              ),
            ),
          );
          expect(
            find.text('1,234 sats'),
            ready && !hidden ? findsOneWidget : findsNothing,
          );
          tester
              .widget<BullBorderedTile>(find.byType(BullBorderedTile))
              .onTap
              ?.call();
          expect(opened, 1);
        },
      );
    }
  }

  testWidgets('missing preferences never reveal the dashboard amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        ArkWalletCard(
          snapshot: ArkSnapshot(
            account: account(),
            revision: 1,
            observedAt: DateTime.utc(2026),
            stale: false,
            spendable: Sats.fromInt(1234),
          ),
          onOpen: () {},
        ),
        amountPreferences: null,
      ),
    );
    expect(find.text('1,234 sats'), findsNothing);
    expect(find.text('••••'), findsOneWidget);
  });
}
