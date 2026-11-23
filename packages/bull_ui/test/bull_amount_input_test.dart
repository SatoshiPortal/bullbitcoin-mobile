import 'dart:ui' show SemanticsAction;

import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

void main() {
  final quotedAt = DateTime.utc(2026, 11, 19, 14, 32);

  testWidgets('the empty amount editor exposes its name and unit', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final canonical = TextEditingController();
    addTearDown(canonical.dispose);
    await tester.pumpWidget(
      wrapWithTheme(
        BullAmountInput(
          canonicalUnit: BitcoinUnit.sats,
          amountController: canonical,
        ),
      ),
    );

    final editor = find.byType(EditableText);
    expect(
      tester.getSemantics(editor).getSemanticsData().label,
      startsWith('Amount '),
    );
    await tester.tap(editor);
    await tester.pump();
    final focused = tester.getSemantics(editor).getSemanticsData();
    expect(focused.label, startsWith('Amount '));
    expect(focused.flagsCollection.isTextField, isTrue);
    expect(focused.hasAction(SemanticsAction.setText), isTrue);
    semantics.dispose();
  });

  testWidgets('Max fiat approximation rounds a half cent up', (tester) async {
    final canonical = TextEditingController(text: '1249580');
    addTearDown(canonical.dispose);
    await tester.pumpWidget(
      wrapWithTheme(
        BullAmountInput(
          canonicalUnit: BitcoinUnit.sats,
          amountController: canonical,
          isMax: true,
          maxAmountSat: BigInt.from(1249580),
          defaultCurrencyCode: 'CAD',
          currencies: [
            BullAmountCurrency(
              code: 'CAD',
              decimals: 2,
              price: 125000,
              priceAt: quotedAt,
            ),
          ],
        ),
      ),
    );
    expect(
      tester.widgetList<Text>(find.byType(Text)).map((text) => text.data),
      contains('≈ 1,561.98 CAD'),
    );
  });

  testWidgets('currency action uses the secondary field style', (tester) async {
    final canonical = TextEditingController(text: '25000');
    addTearDown(canonical.dispose);
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
        ),
      ),
    );
    void expectIcons() {
      final context = tester.element(find.byType(BullAmountInput));
      final icon = tester.widget<Icon>(find.byIcon(Icons.expand_more));
      expect(icon.color, context.bull.onSecondary);
      expect(find.byIcon(Icons.swap_vert), findsNothing);
    }

    expectIcons();
    await tester.tap(find.byTooltip('Currency: Bitcoin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CAD'));
    await tester.pumpAndSettle();
    expectIcons();
  });

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
    await tester.tap(find.byTooltip('Currency: Bitcoin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CAD'));
    await tester.pumpAndSettle();
    expect(canonical.text, '1');
    expect(entry?.sats, BigInt.one);
    expect(entry?.isEdit, isFalse);
    await tester.tap(find.byTooltip('Currency: CAD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bitcoin'));
    await tester.pumpAndSettle();
    expect(canonical.text, '1');
    expect(entry?.sats, BigInt.one);
  });

  testWidgets('an inactive Max update does not replace typed fiat intent', (
    tester,
  ) async {
    final canonical = TextEditingController();
    addTearDown(canonical.dispose);
    Widget host(double price, int max) => wrapWithTheme(
      BullAmountInput(
        canonicalUnit: BitcoinUnit.sats,
        amountController: canonical,
        initialCurrencyCode: 'CAD',
        defaultCurrencyCode: 'CAD',
        maxAmountSat: BigInt.from(max),
        currencies: [
          BullAmountCurrency(
            code: 'CAD',
            decimals: 2,
            price: price,
            priceAt: quotedAt,
          ),
        ],
      ),
    );
    await tester.pumpWidget(host(125000, 50000));
    await tester.enterText(find.byType(TextField), '31.25');
    await tester.pumpWidget(host(125000, 100000));
    await tester.pumpWidget(host(100000, 100000));
    await tester.pump();
    expect(canonical.text, '31250');
    expect(find.text('31.25'), findsOneWidget);
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
    await tester.tap(find.byTooltip('Currency: CAD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bitcoin'));
    await tester.pumpAndSettle();
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
    'currency sheet disables unavailable quotes without changing preferences',
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
      expect(find.text('Always start in CAD'), findsNothing);
      expect(writes, isEmpty);
      expect(startsInFiat, isFalse);
      expect(canonical.text, '25001');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('on a phone the currency sheet scrolls through all choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final canonical = TextEditingController();
    addTearDown(canonical.dispose);
    await tester.pumpWidget(
      wrapWithTheme(
        BullAmountScope(
          snapshot: const BullAmountSnapshot(
            unit: BitcoinUnit.sats,
            hideAmounts: false,
            isReady: true,
            defaultCurrencyCode: 'USD',
            startInFiat: false,
          ),
          writeUnit: (_) async => true,
          writeInputMode: (_) async => true,
          child: Column(
            children: [
              const SizedBox(height: 380),
              BullAmountInput(
                canonicalUnit: BitcoinUnit.sats,
                amountController: canonical,
                currencies: [
                  for (final code in [
                    'USD',
                    'CAD',
                    'MXN',
                    'CRC',
                    'EUR',
                    'ARS',
                    'COP',
                  ])
                    BullAmountCurrency(
                      code: code,
                      decimals: 2,
                      price: 100000,
                      priceAt: quotedAt,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Currency: Bitcoin'));
    await tester.pumpAndSettle();
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(find.text('Always start in Bitcoin'), findsNothing);
    await tester.ensureVisible(find.text('COP'));
    final last = tester.getRect(find.text('COP'));
    expect(last.bottom, lessThanOrEqualTo(screen.height));
    expect(find.byIcon(Icons.check), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a compact row puts its number on the line of its unit', (
    tester,
  ) async {
    final canonical = TextEditingController(text: '40000');
    addTearDown(canonical.dispose);
    await tester.pumpWidget(
      wrapWithTheme(
        Center(
          child: SizedBox(
            width: 150,
            child: BullAmountInput(
              canonicalUnit: BitcoinUnit.sats,
              amountController: canonical,
              compact: true,
              showControls: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final number = tester.getCenter(find.byType(EditableText));
    final unit = tester.getCenter(find.text('sats'));
    expect((number.dy - unit.dy).abs(), lessThan(4));
  });

  testWidgets('in a card the error line takes room only with an error', (
    tester,
  ) async {
    final canonical = TextEditingController(text: '25000');
    addTearDown(canonical.dispose);
    Future<double> height({String? error}) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Center(
            child: BullAmountInput(
              canonicalUnit: BitcoinUnit.sats,
              amountController: canonical,
              inCard: true,
              error: error,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byType(BullAmountInput)).height;
    }

    final plain = await height();
    final withError = await height(error: 'Amount too low');
    expect(find.text('Amount too low'), findsOneWidget);
    expect(withError, greaterThan(plain + 40));
  });
}
