import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'toggle preserves canonical amount and editing uses canonical unit',
    (tester) async {
      final controller = TextEditingController(text: '1');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrapWithTheme(
          BullBitcoinAmountInput(
            currency: 'sats',
            amountController: controller,
            amountEquivalent: '',
            maxLabel: 'MAX',
            switchToBtcLabel: 'Switch to BTC',
            switchToSatsLabel: 'Switch to sats',
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
      wrapWithTheme(
        BullBitcoinAmountInput(
          currency: 'BTC',
          amountController: controller,
          amountEquivalent: '',
          maxLabel: 'MAX',
          switchToBtcLabel: 'BTC',
          switchToSatsLabel: 'sats',
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
    Widget input({bool max = false}) => wrapWithTheme(
      BullBitcoinAmountInput(
        currency: 'sats',
        amountController: controller,
        amountEquivalent: '',
        maxLabel: 'MAX',
        switchToBtcLabel: 'To BTC',
        switchToSatsLabel: 'To sats',
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
      wrapWithTheme(
        BullBitcoinAmountInput(
          currency: 'BTC',
          amountController: controller,
          amountEquivalent: '',
          maxLabel: 'MAX',
          switchToBtcLabel: 'To BTC',
          switchToSatsLabel: 'To sats',
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
      wrapWithTheme(
        BullBitcoinAmountInput(
          currency: 'BTC',
          amountController: controller,
          amountEquivalent: '',
          maxLabel: 'MAX',
          switchToBtcLabel: 'To BTC',
          switchToSatsLabel: 'To sats',
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '0.000000001');
    await tester.pump();
    expect(controller.text, '1');
  });
  testWidgets(
    'global changes and undo reset input units without changing canonical amounts',
    (tester) async {
      final controller = TextEditingController(text: '123');
      final maxController = TextEditingController(text: '456');
      addTearDown(controller.dispose);
      addTearDown(maxController.dispose);
      BullAmountPreferences preferences(BullAmountUnit unit) =>
          BullAmountPreferences(
            defaultUnit: unit,
            changeDefaultUnit: (_) async => true,
            globalActionLabel: 'Change default',
            tooltip: 'Change unit',
            satsEverywhereMessage: 'Sats',
            btcEverywhereMessage: 'BTC',
            undoLabel: 'Undo',
            failureMessage: 'Failed',
          );
      Widget host(BullAmountUnit unit) => wrapWithTheme(
        BullAmountPreferencesScope(
          preferences: preferences(unit),
          child: Column(
            children: [
              BullBitcoinAmountInput(
                currency: 'sats',
                amountController: controller,
                amountEquivalent: '',
                maxLabel: 'MAX',
                switchToBtcLabel: 'To BTC',
                switchToSatsLabel: 'To sats',
              ),
              BullBitcoinAmountInput(
                currency: 'sats',
                amountController: maxController,
                amountEquivalent: '',
                maxLabel: 'MAX',
                switchToBtcLabel: 'To BTC',
                switchToSatsLabel: 'To sats',
                isMax: true,
                readOnly: true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(host(BullAmountUnit.sats));
      await tester.tap(find.text('sats').first);
      await tester.pump();
      expect(find.text('0.00000123'), findsOneWidget);
      await tester.pumpWidget(host(BullAmountUnit.btc));
      expect(find.text('BTC'), findsNWidgets(2));
      expect(find.text('0.00000123'), findsOneWidget);
      expect(controller.text, '123');
      expect(maxController.text, '456');
      await tester.pumpWidget(host(BullAmountUnit.sats));
      expect(find.text('sats'), findsNWidgets(2));
      expect(find.text('123'), findsOneWidget);
      expect(find.text('MAX'), findsOneWidget);
      expect(controller.text, '123');
      expect(maxController.text, '456');
    },
  );

  testWidgets(
    'global reset discards incomplete text without interpreting it in the new unit',
    (tester) async {
      final controller = TextEditingController(text: '1');
      addTearDown(controller.dispose);
      Widget host(BullAmountUnit unit) => wrapWithTheme(
        BullAmountPreferencesScope(
          preferences: BullAmountPreferences(
            defaultUnit: unit,
            changeDefaultUnit: (_) async => true,
            globalActionLabel: 'Change default',
            tooltip: 'Change unit',
            satsEverywhereMessage: 'Sats',
            btcEverywhereMessage: 'BTC',
            undoLabel: 'Undo',
            failureMessage: 'Failed',
          ),
          child: BullBitcoinAmountInput(
            currency: 'BTC',
            amountController: controller,
            amountEquivalent: '',
            maxLabel: 'MAX',
            switchToBtcLabel: 'To BTC',
            switchToSatsLabel: 'To sats',
          ),
        ),
      );
      await tester.pumpWidget(host(BullAmountUnit.btc));
      await tester.enterText(find.byType(TextField), '1.');
      expect(controller.text, isEmpty);
      await tester.pumpWidget(host(BullAmountUnit.sats));
      expect(controller.text, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
      expect(find.text('sats'), findsOneWidget);
    },
  );

  testWidgets(
    'same-value global reset clears override but ordinary rebuild does not',
    (tester) async {
      final controller = TextEditingController(text: '123');
      addTearDown(controller.dispose);
      VoidCallback? reset;
      Widget host() => wrapWithTheme(
        BullAmountPreferencesScope(
          preferences: BullAmountPreferences(
            defaultUnit: BullAmountUnit.sats,
            changeDefaultUnit: (_) async => true,
            globalActionLabel: 'Change default',
            tooltip: 'Change unit',
            satsEverywhereMessage: 'Sats',
            btcEverywhereMessage: 'BTC',
            undoLabel: 'Undo',
            failureMessage: 'Failed',
          ),
          child: Builder(
            builder: (context) {
              reset = BullAmountPreferencesScope.resetterOf(context);
              return BullBitcoinAmountInput(
                currency: 'sats',
                amountController: controller,
                amountEquivalent: '',
                maxLabel: 'MAX',
                switchToBtcLabel: 'To BTC',
                switchToSatsLabel: 'To sats',
              );
            },
          ),
        ),
      );
      await tester.pumpWidget(host());
      await tester.tap(find.text('sats'));
      await tester.pump();
      expect(find.text('0.00000123'), findsOneWidget);
      await tester.pumpWidget(host());
      expect(find.text('0.00000123'), findsOneWidget);
      expect(reset, isNotNull);
      reset?.call();
      await tester.pump();
      expect(find.text('123'), findsOneWidget);
      expect(find.text('sats'), findsOneWidget);
      expect(controller.text, '123');
    },
  );
}
