import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  testWidgets(
    'toggle preserves canonical amount and editing uses canonical unit',
    (tester) async {
      final controller = TextEditingController(text: '1');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrapInput(
          BullBitcoinAmountInput(
            canonicalUnit: BitcoinUnit.sats,
            amountController: controller,
            amountEquivalent: '',
          ),
        ),
      );
      await tester.tap(find.text('sats'));
      await tester.pump();
      expect(controller.text, '1');
      expect(find.text('0.00000001'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1.00000001');
      await tester.pump();
      expect(controller.text, '100000001');
      controller.text = '200000000';
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.text('BTC'));
      await tester.pump();
      expect(find.text('200000000'), findsOneWidget);
    },
  );

  testWidgets('incomplete input invalidates the canonical value', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrapInput(
        BullBitcoinAmountInput(
          canonicalUnit: BitcoinUnit.btc,
          amountController: controller,
          amountEquivalent: '',
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '1.1');
    expect(controller.text, '1.1');
    await tester.enterText(find.byType(TextField), '1.');
    await tester.tap(find.text('BTC'));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('BTC'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1.2');
    expect(controller.text, '1.2');
  });
  testWidgets('empty and MAX toggle without changing canonical amount', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    Widget input({bool max = false}) => wrapInput(
      BullBitcoinAmountInput(
        canonicalUnit: BitcoinUnit.sats,
        amountController: controller,
        amountEquivalent: '',
        isMax: max,
        readOnly: max,
      ),
    );
    await tester.pumpWidget(input());
    await tester.tap(find.text('sats'));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(find.text('BTC'), findsOneWidget);
    controller.text = '123';
    await tester.pumpWidget(input(max: true));
    await tester.pump();
    expect(find.text('MAX'), findsOneWidget);
    await tester.tap(find.text('BTC'));
    await tester.pump();
    expect(controller.text, '123');
  });

  testWidgets('composition blocks toggle until committed', (tester) async {
    final controller = TextEditingController(text: '1');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrapInput(
        BullBitcoinAmountInput(
          canonicalUnit: BitcoinUnit.btc,
          amountController: controller,
          amountEquivalent: '',
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '2',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('BTC'));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('BTC'), findsOneWidget);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '2',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(controller.text, '2');
  });

  testWidgets('overprecision paste is rejected without rounding', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrapInput(
        BullBitcoinAmountInput(
          canonicalUnit: BitcoinUnit.btc,
          amountController: controller,
          amountEquivalent: '',
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '0.000000001');
    await tester.pump();
    expect(controller.text, '1');
  });

  testWidgets('a BTC amount can start with the decimal separator', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrapInput(
        BullBitcoinAmountInput(
          canonicalUnit: BitcoinUnit.btc,
          amountController: controller,
          amountEquivalent: '',
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '.01');
    await tester.pump();
    expect(find.text('0.01'), findsOneWidget);
    expect(controller.text, '0.01');
  });
  testWidgets('focused draft and selection survive global changes until blur', (
    tester,
  ) async {
    final canonical = TextEditingController(text: '10000');
    final focus = FocusNode();
    addTearDown(canonical.dispose);
    addTearDown(focus.dispose);
    Widget host(BitcoinUnit unit) => wrapInput(
      BullAmountScope(
        snapshot: BullAmountSnapshot(
          unit: unit,
          hideAmounts: false,
          isReady: true,
        ),
        writeUnit: (_) async => true,
        child: BullBitcoinAmountInput(
          canonicalUnit: BitcoinUnit.sats,
          amountController: canonical,
          amountEquivalent: '',
          focusNode: focus,
        ),
      ),
    );
    await tester.pumpWidget(host(BitcoinUnit.sats));
    focus.requestFocus();
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '12345',
        selection: TextSelection(baseOffset: 1, extentOffset: 3),
      ),
    );
    await tester.pump();
    final display = _displayController(tester);
    final before = display.value;
    await tester.pumpWidget(host(BitcoinUnit.btc));
    expect(display.value, before);
    expect(find.text('sats'), findsOneWidget);
    expect(canonical.text, '12345');
    focus.unfocus();
    await tester.pump();
    await tester.pump();
    expect(display.text, '0.00012345');
    expect(find.text('BTC'), findsOneWidget);
    expect(canonical.text, '12345');
  });

  testWidgets(
    'inactive input follows defaults and preserves canonical amount',
    (tester) async {
      final canonical = TextEditingController(text: '10000');
      addTearDown(canonical.dispose);
      Widget host(BitcoinUnit unit) => wrapInput(
        BullAmountScope(
          snapshot: BullAmountSnapshot(
            unit: unit,
            hideAmounts: false,
            isReady: true,
          ),
          writeUnit: (_) async => true,
          child: BullBitcoinAmountInput(
            canonicalUnit: BitcoinUnit.sats,
            amountController: canonical,
            amountEquivalent: '',
          ),
        ),
      );
      await tester.pumpWidget(host(BitcoinUnit.sats));
      await tester.pumpWidget(host(BitcoinUnit.btc));
      expect(find.text('0.0001'), findsOneWidget);
      expect(find.text('BTC'), findsOneWidget);
      expect(canonical.text, '10000');
    },
  );

  testWidgets('composing and incomplete drafts survive global change', (
    tester,
  ) async {
    final canonical = TextEditingController(text: '1');
    final focus = FocusNode();
    addTearDown(canonical.dispose);
    addTearDown(focus.dispose);
    Widget host(BitcoinUnit unit) => wrapInput(
      BullAmountScope(
        snapshot: BullAmountSnapshot(
          unit: unit,
          hideAmounts: false,
          isReady: true,
        ),
        writeUnit: (_) async => true,
        child: BullBitcoinAmountInput(
          canonicalUnit: BitcoinUnit.btc,
          amountController: canonical,
          amountEquivalent: '',
          focusNode: focus,
        ),
      ),
    );
    await tester.pumpWidget(host(BitcoinUnit.btc));
    focus.requestFocus();
    await tester.pump();
    const composing = TextEditingValue(
      text: '1.',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 0, end: 2),
    );
    tester.testTextInput.updateEditingValue(composing);
    await tester.pump();
    await tester.pumpWidget(host(BitcoinUnit.sats));
    expect(_displayController(tester).value, composing);
    expect(find.text('BTC'), findsOneWidget);
    expect(canonical.text, isEmpty);
  });

  testWidgets('replacing an external focus node follows the new node', (
    tester,
  ) async {
    final canonical = TextEditingController(text: '10000');
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(canonical.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Widget host(BitcoinUnit unit, FocusNode node) => wrapInput(
      BullAmountScope(
        snapshot: BullAmountSnapshot(
          unit: unit,
          hideAmounts: false,
          isReady: true,
        ),
        writeUnit: (_) async => true,
        child: BullBitcoinAmountInput(
          canonicalUnit: BitcoinUnit.sats,
          amountController: canonical,
          amountEquivalent: '',
          focusNode: node,
        ),
      ),
    );
    await tester.pumpWidget(host(BitcoinUnit.sats, first));
    await tester.pumpWidget(host(BitcoinUnit.sats, second));
    second.requestFocus();
    await tester.pump();
    await tester.pumpWidget(host(BitcoinUnit.btc, second));
    expect(find.text('10000'), findsOneWidget);
    second.unfocus();
    await tester.pump();
    expect(find.text('0.0001'), findsOneWidget);
    expect(canonical.text, '10000');
  });

  testWidgets('internal focus retains empty draft until blur', (tester) async {
    final canonical = TextEditingController();
    addTearDown(canonical.dispose);
    Widget host(BitcoinUnit unit) => wrapInput(
      BullAmountScope(
        snapshot: BullAmountSnapshot(
          unit: unit,
          hideAmounts: false,
          isReady: true,
        ),
        writeUnit: (_) async => true,
        child: BullBitcoinAmountInput(
          canonicalUnit: BitcoinUnit.sats,
          amountController: canonical,
          amountEquivalent: '',
        ),
      ),
    );
    await tester.pumpWidget(host(BitcoinUnit.sats));
    await tester.tap(find.byType(TextField));
    await tester.pumpWidget(host(BitcoinUnit.btc));
    expect(_displayController(tester).text, isEmpty);
    expect(find.text('sats'), findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.text('BTC'), findsOneWidget);
    expect(canonical.text, isEmpty);
  });

  testWidgets('incomplete draft stays intact on blur', (tester) async {
    final canonical = TextEditingController(text: '1');
    final focus = FocusNode();
    addTearDown(canonical.dispose);
    addTearDown(focus.dispose);
    Widget host(BitcoinUnit unit) => wrapInput(
      BullAmountScope(
        snapshot: BullAmountSnapshot(
          unit: unit,
          hideAmounts: false,
          isReady: true,
        ),
        writeUnit: (_) async => true,
        child: BullBitcoinAmountInput(
          canonicalUnit: BitcoinUnit.btc,
          amountController: canonical,
          amountEquivalent: '',
          focusNode: focus,
        ),
      ),
    );
    await tester.pumpWidget(host(BitcoinUnit.btc));
    await tester.enterText(find.byType(TextField), '1.');
    await tester.pumpWidget(host(BitcoinUnit.sats));
    focus.unfocus();
    await tester.pump();
    expect(_displayController(tester).text, '1.');
    expect(find.text('BTC'), findsOneWidget);
    expect(canonical.text, isEmpty);
  });

  testWidgets('MAX follows global unit without changing canonical value', (
    tester,
  ) async {
    final canonical = TextEditingController(text: '10000');
    addTearDown(canonical.dispose);
    Widget host(BitcoinUnit unit) => wrapInput(
      BullAmountScope(
        snapshot: BullAmountSnapshot(
          unit: unit,
          hideAmounts: false,
          isReady: true,
        ),
        writeUnit: (_) async => true,
        child: BullBitcoinAmountInput(
          canonicalUnit: BitcoinUnit.sats,
          amountController: canonical,
          amountEquivalent: '',
          isMax: true,
          readOnly: true,
        ),
      ),
    );
    await tester.pumpWidget(host(BitcoinUnit.sats));
    await tester.pumpWidget(host(BitcoinUnit.btc));
    expect(find.text('MAX'), findsOneWidget);
    expect(find.text('BTC'), findsOneWidget);
    expect(canonical.text, '10000');
  });

  testWidgets('same-unit generation reset waits for blur', (tester) async {
    var writes = 0;
    final canonical = TextEditingController(text: '10000');
    final focus = FocusNode();
    addTearDown(canonical.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      wrapInput(
        BullAmountScope(
          snapshot: const BullAmountSnapshot(
            unit: BitcoinUnit.sats,
            hideAmounts: false,
            isReady: true,
          ),
          writeUnit: (_) async {
            writes++;
            return true;
          },
          child: BullBitcoinAmountInput(
            canonicalUnit: BitcoinUnit.sats,
            amountController: canonical,
            amountEquivalent: '',
            focusNode: focus,
          ),
        ),
      ),
    );
    await tester.tap(find.text('sats'));
    await tester.pump();
    focus.requestFocus();
    await tester.pump();
    await tester.longPress(find.text('BTC'));
    await tester.pump();
    await tester.pump();
    expect(find.text('0.0001'), findsOneWidget);
    expect(find.text('BTC'), findsOneWidget);
    expect(canonical.text, '10000');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump();
    expect(find.text('0.0001'), findsOneWidget);
    expect(find.text('BTC'), findsOneWidget);
    expect(writes, 2);
    focus.unfocus();
    await tester.pump();
    expect(find.text('10000'), findsOneWidget);
    expect(find.text('sats'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final target in BitcoinUnit.values) {
    testWidgets(
      'next focus applies $target to an incomplete canonical-empty draft',
      (tester) async {
        final canonical = TextEditingController(text: '1');
        final focus = FocusNode();
        addTearDown(canonical.dispose);
        addTearDown(focus.dispose);
        Widget host(BitcoinUnit unit) => wrapInput(
          BullAmountScope(
            snapshot: BullAmountSnapshot(
              unit: unit,
              hideAmounts: false,
              isReady: true,
            ),
            writeUnit: (_) async => true,
            child: BullBitcoinAmountInput(
              canonicalUnit: BitcoinUnit.btc,
              amountController: canonical,
              amountEquivalent: '',
              focusNode: focus,
            ),
          ),
        );
        await tester.pumpWidget(host(BitcoinUnit.btc));
        await tester.enterText(find.byType(TextField), '1.');
        await tester.pumpWidget(host(BitcoinUnit.sats));
        await tester.pumpWidget(host(target));
        focus.unfocus();
        await tester.pump();
        expect(_displayController(tester).text, '1.');
        focus.requestFocus();
        await tester.pump();
        expect(_displayController(tester).text, isEmpty);
        expect(find.text(target.code), findsOneWidget);
        expect(canonical.text, isEmpty);
      },
    );
  }

  testWidgets(
    'blur commits composition in its original unit before applying default',
    (tester) async {
      final canonical = TextEditingController(text: '1');
      final focus = FocusNode();
      addTearDown(canonical.dispose);
      addTearDown(focus.dispose);
      Widget host(BitcoinUnit unit) => wrapInput(
        BullAmountScope(
          snapshot: BullAmountSnapshot(
            unit: unit,
            hideAmounts: false,
            isReady: true,
          ),
          writeUnit: (_) async => true,
          child: BullBitcoinAmountInput(
            canonicalUnit: BitcoinUnit.btc,
            amountController: canonical,
            amountEquivalent: '',
            focusNode: focus,
          ),
        ),
      );
      await tester.pumpWidget(host(BitcoinUnit.btc));
      focus.requestFocus();
      await tester.pump();
      const composing = TextEditingValue(
        text: '2',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pump();
      await tester.pumpWidget(host(BitcoinUnit.sats));
      expect(_displayController(tester).value, composing);
      expect(canonical.text, isEmpty);
      focus.unfocus();
      await tester.pump();
      await tester.pump();
      expect(_displayController(tester).text, '200000000');
      expect(find.text('sats'), findsOneWidget);
      expect(canonical.text, '2');
    },
  );
}

Widget wrapInput(Widget child) => MaterialApp(
  localizationsDelegates: BullUiLocalizations.localizationsDelegates,
  supportedLocales: BullUiLocalizations.supportedLocales,
  theme: ThemeData(extensions: testBullExtensions),
  home: Scaffold(body: child),
);

TextEditingController _displayController(WidgetTester tester) {
  final controller = tester
      .widget<TextField>(find.byType(TextField))
      .controller;
  expect(controller, isNotNull);
  if (controller == null) throw StateError('Missing display controller');
  return controller;
}
