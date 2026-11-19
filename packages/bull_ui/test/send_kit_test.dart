import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

void main() {
  testWidgets(
    'field action keeps its visual size and accessible touch target',
    (tester) async {
      var taps = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWithTheme(BullFieldAction(label: 'MAX', onPressed: () => taps++)),
      );
      expect(tester.getSize(find.byType(BullFieldAction)), const Size(48, 48));
      final fill = find.descendant(
        of: find.byType(BullFieldAction),
        matching: find.byType(Container),
      );
      expect(tester.getSize(fill), const Size(48, 40));
      expect(
        tester.getSemantics(find.byType(BullFieldAction)),
        matchesSemantics(
          label: 'MAX',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
      await tester.tap(find.byType(BullFieldAction));
      expect(taps, 1);
      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    },
  );

  testWidgets('step markers expose their progress and support large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrapWithTheme(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: BullStepBar(
            labels: const ['Recipient', 'Amount', 'Confirm'],
            currentStep: 1,
            semanticLabel: (index, label) => 'Step ${index + 1} of 3: $label',
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 2 of 3: Amount'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('empty supporting text does not mask an explicit zero or MAX', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    Widget editor({bool max = false}) => wrapWithTheme(
      BullAmountInput(
        canonicalUnit: BitcoinUnit.sats,
        amountController: controller,
        emptyEquivalent: 'Optional',
        inCard: true,
        isMax: max,
        maxAmountSat: BigInt.from(10000),
        currencies: [
          BullAmountCurrency(
            code: 'CAD',
            decimals: 2,
            price: 100000,
            priceAt: DateTime.utc(2026, 11, 19),
          ),
        ],
        defaultCurrencyCode: 'CAD',
      ),
    );
    await tester.pumpWidget(editor());
    expect(find.text('Optional'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).style?.fontSize,
      28,
    );
    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();
    expect(find.text('Optional'), findsNothing);
    expect(find.text('≈ 0.00 CAD'), findsOneWidget);
    controller.clear();
    await tester.pump();
    expect(find.text('Optional'), findsOneWidget);
    await tester.pumpWidget(editor(max: true));
    expect(find.text('Optional'), findsNothing);
    expect(find.text('≈ 10.00 CAD'), findsOneWidget);
    await tester.tap(find.text('sats'));
    await tester.pump();
    expect(find.text('BTC'), findsOneWidget);
    expect(controller.text, isEmpty);
  });

  testWidgets('framed amount errors stay below its value and border', (
    tester,
  ) async {
    final controller = TextEditingController(text: '25000');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrapWithTheme(
        BullAmountInput(
          canonicalUnit: BitcoinUnit.sats,
          amountController: controller,
          framed: true,
          error: 'Not enough funds',
        ),
      ),
    );
    final value = tester.getRect(find.byType(TextField));
    final error = tester.getRect(find.text('Not enough funds'));
    final frames = find.descendant(
      of: find.byType(BullAmountInput),
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.decoration is BoxDecoration,
      ),
    );
    final frame = tester.getRect(frames.first);
    expect(error.top, greaterThan(frame.bottom));
    expect(error.top, greaterThan(value.bottom));
    final context = tester.element(find.byType(BullAmountInput));
    final text = tester.widget<Text>(find.text('Not enough funds'));
    expect(text.style?.color, context.bull.error);
    expect(text.style?.fontSize, context.bullType.label.fontSize);
    expect(
      tester.widget<TextField>(find.byType(TextField)).style?.fontSize,
      28,
    );
  });

  testWidgets('picker selection has a neutral fill and muted subtitle', (
    tester,
  ) async {
    var picked = false;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrapWithTheme(
        BullPickerRow(
          label: 'Savings',
          subtitle: 'New address',
          selected: true,
          onPressed: () => picked = true,
        ),
      ),
    );
    final context = tester.element(find.byType(BullPickerRow));
    final title = tester.widget<Text>(find.text('Savings'));
    expect(title.style?.color, context.bull.primary);
    expect(title.style?.fontWeight, FontWeight.w500);
    expect(
      tester.widget<Text>(find.text('New address')).style?.color,
      context.bull.textMuted,
    );
    expect(find.byIcon(Icons.check), findsNothing);
    await tester.tap(find.text('Savings'));
    expect(picked, isTrue);
    expect(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });
}
