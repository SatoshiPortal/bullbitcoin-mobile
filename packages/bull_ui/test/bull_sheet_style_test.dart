import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    bool redesign = false,
    Color? barrier,
    Color? background,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          extensions: testBullExtensions,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => BullInlineTextButton(
              child: const Text('Open sheet'),
              onPressed: () => BullBottomSheet.show<void>(
                context: context,
                style: redesign ? BullSheetStyle.redesign(context) : null,
                barrierColor: barrier,
                backgroundColor: background,
                child: const SizedBox(
                  height: 100,
                  child: Text('Sheet content'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
  }

  Color? barrierColor(WidgetTester tester) => tester
      .widgetList<ModalBarrier>(find.byType(ModalBarrier))
      .where((barrier) => barrier.color != null)
      .last
      .color;
  Color? surfaceColor(WidgetTester tester) =>
      tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor;

  for (final brightness in Brightness.values) {
    testWidgets('shared redesign sheet colors in $brightness', (tester) async {
      await open(tester, brightness: brightness, redesign: true);
      expect(
        barrierColor(tester),
        testBullTheme.scrim.withValues(
          alpha: brightness == Brightness.dark ? 0.60 : 0.45,
        ),
      );
      expect(
        surfaceColor(tester),
        brightness == Brightness.light
            ? testBullTheme.background
            : testBullTheme.surface,
      );
    });
  }

  testWidgets('legacy sheet colors remain the default', (tester) async {
    await open(tester);
    expect(barrierColor(tester), testBullTheme.surface.withAlpha(100));
    expect(surfaceColor(tester), testBullTheme.background);
  });

  testWidgets('explicit colors override the shared style independently', (
    tester,
  ) async {
    final custom = testBullTheme.primary.withValues(alpha: 0.2);
    await open(tester, redesign: true, barrier: custom);
    expect(barrierColor(tester), custom);
    expect(surfaceColor(tester), testBullTheme.background);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await open(tester, redesign: true, background: testBullTheme.secondary);
    expect(barrierColor(tester), testBullTheme.scrim.withValues(alpha: 0.45));
    expect(surfaceColor(tester), testBullTheme.secondary);
  });

  for (final redesign in [false, true]) {
    testWidgets('currency sheet style is opt-in: $redesign', (tester) async {
      final canonical = TextEditingController(text: '10000');
      addTearDown(canonical.dispose);
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) => BullAmountInput(
              canonicalUnit: BitcoinUnit.sats,
              amountController: canonical,
              currencies: [
                BullAmountCurrency(
                  code: 'CAD',
                  decimals: 2,
                  price: 100000,
                  priceAt: DateTime.utc(2026, 11, 19),
                ),
              ],
              currencySheetStyle: redesign
                  ? BullSheetStyle.redesign(context)
                  : null,
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Currency: Bitcoin'));
      await tester.pumpAndSettle();
      expect(
        barrierColor(tester),
        redesign
            ? testBullTheme.scrim.withValues(alpha: 0.45)
            : testBullTheme.surface.withAlpha(100),
      );
      expect(surfaceColor(tester), testBullTheme.background);
    });
  }
}
