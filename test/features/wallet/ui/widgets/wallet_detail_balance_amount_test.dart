import 'package:overview/overview.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  testWidgets('detail never renders digits before preferences are ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        BullAmountScope(
          snapshot: const BullAmountSnapshot(
            unit: BitcoinUnit.sats,
            hideAmounts: false,
            isReady: false,
          ),
          writeUnit: (_) async => true,
          child: const WalletDetailBalanceAmount(balanceSat: 12345),
        ),
      ),
    );
    expect(find.textContaining('12,345'), findsNothing);
    expect(find.byType(BullAmountUnitToggle), findsOneWidget);
  });

  testWidgets('tap switches the unit, long press changes the default', (
    tester,
  ) async {
    final written = <BitcoinUnit>[];
    await tester.pumpWidget(
      wrapWithTheme(
        BullAmountScope(
          snapshot: const BullAmountSnapshot(
            unit: BitcoinUnit.sats,
            hideAmounts: false,
            isReady: true,
          ),
          writeUnit: (unit) async {
            written.add(unit);
            return true;
          },
          child: const WalletDetailBalanceAmount(balanceSat: 12345),
        ),
      ),
    );

    await tester.tap(find.text('12,345 sats'));
    await tester.pump();
    expect(find.text('0.00012345 BTC'), findsOneWidget);

    await tester.longPress(find.text('0.00012345 BTC'));
    await tester.pump();
    expect(written, [BitcoinUnit.sats]);
  });
}
