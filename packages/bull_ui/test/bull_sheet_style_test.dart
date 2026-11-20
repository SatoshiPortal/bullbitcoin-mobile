import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

void main() {
  testWidgets('currency sheets use global modal defaults without an opt-in', (
    tester,
  ) async {
    final controller = TextEditingController(text: '10000');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrapWithTheme(
        BullAmountInput(
          canonicalUnit: BitcoinUnit.sats,
          amountController: controller,
          currencies: [
            BullAmountCurrency(
              code: 'CAD',
              decimals: 2,
              price: 100000,
              priceAt: DateTime.utc(2026, 11, 19),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byTooltip('Currency: Bitcoin'));
    await tester.pumpAndSettle();
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.backgroundColor, testBullTheme.background);
    expect((sheet.shape as RoundedRectangleBorder?)?.side, BorderSide.none);
    final barrier = tester
        .widgetList<ModalBarrier>(find.byType(ModalBarrier))
        .where((barrier) => barrier.color != null)
        .last;
    expect(barrier.color, testBullTheme.scrim.withValues(alpha: 0.45));
  });
}
