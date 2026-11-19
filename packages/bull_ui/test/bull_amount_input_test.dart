import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

void main() {
  final quotedAt = DateTime.utc(2026, 11, 19, 14, 32);

  testWidgets('representation round trips preserve one satoshi', (
    tester,
  ) async {
    final canonical = TextEditingController(text: '1');
    addTearDown(canonical.dispose);
    BullAmountInputValue? entry;
    await tester.pumpWidget(
      wrapWithTheme(
        BullAmountInput(
          canonicalUnit: BitcoinUnit.sats,
          amountController: canonical,
          defaultCurrencyCode: 'CAD',
          currencies: [
            BullAmountCurrency(
              code: 'CAD',
              decimals: 2,
              price: 125000,
              priceAt: quotedAt,
            ),
          ],
          onEntryChanged: (value) => entry = value,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Enter the amount in CAD'));
    await tester.pump();
    expect(canonical.text, '1');
    expect(entry?.sats, BigInt.one);
    expect(entry?.isEdit, isFalse);
    await tester.tap(find.byTooltip('Enter the amount in bitcoin'));
    await tester.pump();
    expect(canonical.text, '1');
    expect(entry?.sats, BigInt.one);
  });

  testWidgets('fiat intent is repriced until the caller freezes it', (
    tester,
  ) async {
    final canonical = TextEditingController();
    addTearDown(canonical.dispose);
    BullAmountInputValue? entry;
    Widget host(double? price) => wrapWithTheme(
      BullAmountInput(
        canonicalUnit: BitcoinUnit.sats,
        amountController: canonical,
        initialCurrencyCode: 'CAD',
        defaultCurrencyCode: 'CAD',
        currencies: [
          BullAmountCurrency(
            code: 'CAD',
            decimals: 2,
            price: price,
            priceAt: quotedAt,
          ),
        ],
        onEntryChanged: (value) => entry = value,
      ),
    );
    await tester.pumpWidget(host(125000));
    await tester.enterText(find.byType(TextField), '31.25');
    expect(canonical.text, '25000');
    await tester.pumpWidget(host(100000));
    await tester.pump();
    expect(canonical.text, '31250');
    expect(find.text('31.25'), findsOneWidget);
    expect(entry?.price, 100000);
    expect(entry?.priceAt, quotedAt);
    await tester.pumpWidget(host(null));
    await tester.pump();
    expect(entry?.isValid, isFalse);
    expect(find.text('≈ — sats'), findsOneWidget);
    expect(find.text('31.25'), findsOneWidget);
    await tester.pumpWidget(host(125000));
    await tester.pump();
    expect(entry?.isValid, isTrue);
    expect(canonical.text, '25000');
  });

  testWidgets('no quote cannot turn an unknown fiat edit into bitcoin', (
    tester,
  ) async {
    final canonical = TextEditingController();
    addTearDown(canonical.dispose);
    BullAmountInputValue? entry;
    await tester.pumpWidget(
      wrapWithTheme(
        BullAmountInput(
          canonicalUnit: BitcoinUnit.sats,
          amountController: canonical,
          initialCurrencyCode: 'CAD',
          defaultCurrencyCode: 'CAD',
          currencies: const [BullAmountCurrency(code: 'CAD', decimals: 2)],
          onEntryChanged: (value) => entry = value,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '12.50');
    expect(canonical.text, isEmpty);
    expect(entry?.isValid, isFalse);
    await tester.tap(find.byTooltip('Enter the amount in bitcoin'));
    await tester.pump();
    expect(canonical.text, isEmpty);
    expect(entry?.sats, isNull);
  });

  testWidgets('Max tracks fee estimates and editing exits the intent', (
    tester,
  ) async {
    final canonical = TextEditingController(text: '10000');
    addTearDown(canonical.dispose);
    BullAmountInputValue? entry;
    Widget host(int spendable) => wrapWithTheme(
      BullAmountInput(
        canonicalUnit: BitcoinUnit.sats,
        amountController: canonical,
        isMax: true,
        maxAmountSat: BigInt.from(spendable),
        onEntryChanged: (value) => entry = value,
      ),
    );
    await tester.pumpWidget(host(9580));
    await tester.pump();
    expect(entry?.isMax, isTrue);
    expect(entry?.sats, BigInt.from(9580));
    await tester.pumpWidget(host(9500));
    await tester.pump();
    expect(entry?.sats, BigInt.from(9500));
    await tester.enterText(find.byType(TextField), '12');
    expect(entry?.isMax, isFalse);
    expect(canonical.text, '12');
    await tester.pumpWidget(host(9400));
    await tester.pump();
    expect(canonical.text, '12');
    expect(find.text('12'), findsOneWidget);
  });
  testWidgets('a refreshed quote publishes safely to an ancestor', (
    tester,
  ) async {
    final canonical = TextEditingController();
    addTearDown(canonical.dispose);
    late StateSetter publish;
    var price = 125000.0;
    var notifications = 0;
    await tester.pumpWidget(
      wrapWithTheme(
        StatefulBuilder(
          builder: (context, update) {
            publish = update;
            return BullAmountInput(
              canonicalUnit: BitcoinUnit.sats,
              amountController: canonical,
              initialCurrencyCode: 'CAD',
              defaultCurrencyCode: 'CAD',
              currencies: [
                BullAmountCurrency(
                  code: 'CAD',
                  decimals: 2,
                  price: price,
                  priceAt: quotedAt,
                ),
              ],
            );
          },
        ),
      ),
    );
    canonical.addListener(() => publish(() => notifications++));
    await tester.enterText(find.byType(TextField), '31.25');
    await tester.pump();
    publish(() => price = 100000);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(canonical.text, '31250');
    expect(notifications, 2);
  });

  testWidgets(
    'currency menu disables unavailable quotes and persists the default with Undo',
    (tester) async {
      final canonical = TextEditingController(text: '25001');
      addTearDown(canonical.dispose);
      final writes = <bool>[];
      var startsInFiat = false;
      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, update) {
              return BullAmountScope(
                snapshot: BullAmountSnapshot(
                  unit: BitcoinUnit.sats,
                  hideAmounts: false,
                  isReady: true,
                  defaultCurrencyCode: 'CAD',
                  startInFiat: startsInFiat,
                ),
                writeUnit: (_) async => true,
                writeInputMode: (target) async {
                  writes.add(target);
                  update(() => startsInFiat = target);
                  return true;
                },
                child: BullAmountInput(
                  canonicalUnit: BitcoinUnit.sats,
                  amountController: canonical,
                  currencies: [
                    BullAmountCurrency(
                      code: 'CAD',
                      decimals: 2,
                      price: 125000,
                      priceAt: quotedAt,
                    ),
                    const BullAmountCurrency(code: 'EUR', decimals: 2),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.byTooltip('Currency: Bitcoin'));
      await tester.pumpAndSettle();
      expect(find.text('No price available'), findsOneWidget);
      await tester.tap(find.text('EUR'));
      await tester.pumpAndSettle();
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(canonical.text, '25001');
      await tester.tap(find.text('CAD'));
      await tester.pumpAndSettle();
      expect(canonical.text, '25001');
      await tester.tap(find.byTooltip('Currency: CAD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Always start in CAD'));
      await tester.pumpAndSettle();
      expect(writes, [true]);
      expect(startsInFiat, isTrue);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(writes, [true, false]);
      expect(startsInFiat, isFalse);
      expect(canonical.text, '25001');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
