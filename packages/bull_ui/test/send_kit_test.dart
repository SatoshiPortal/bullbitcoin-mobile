import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
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
        matching: find.byType(Ink),
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

  testWidgets('step bar wraps long labels at normal text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        BullStepBar(
          labels: const ['Payment recipient', 'Payment amount', 'Confirmation'],
          currentStep: 0,
          semanticLabel: (index, label) => label,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Payment recipient'), findsOneWidget);
  });

  testWidgets('selected dropdown fill covers the whole clickable menu row', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        BullPickerChip<String>(
          value: 'a',
          onChanged: (_) {},
          items: const [
            BullPickerItem(value: 'a', label: 'Apple'),
            BullPickerItem(value: 'b', label: 'A much longer currency label'),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();
    final selected = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.color == testBullTheme.textMuted.withValues(alpha: 0.1),
    );
    final item = find.ancestor(
      of: find.text('Apple').last,
      matching: find.byType(PopupMenuItem<int>),
    );
    expect(tester.getRect(selected), tester.getRect(item));
    expect(tester.takeException(), isNull);
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

  testWidgets('amount without currencies has no currency sheet action', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrapWithTheme(
        BullAmountInput(
          canonicalUnit: BitcoinUnit.sats,
          amountController: controller,
        ),
      ),
    );
    expect(find.byTooltip('Currency: Bitcoin'), findsNothing);
    expect(find.text('sats'), findsOneWidget);
  });

  testWidgets(
    'MAX sheet explains fiat lock separately from the Bitcoin subtitle',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrapWithTheme(
          BullAmountInput(
            canonicalUnit: BitcoinUnit.sats,
            amountController: controller,
            isMax: true,
            maxAmountSat: BigInt.from(10000),
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
      expect(find.text('Finish entering the amount'), findsNothing);
      expect(find.text('Leave MAX to enter a fiat amount'), findsOneWidget);
      expect(find.text('BTC or sats'), findsOneWidget);
      final sheet = tester.widget<BullPickerSheet<BullPickerItem<String>>>(
        find.byType(BullPickerSheet<BullPickerItem<String>>),
      );
      expect(sheet.options.first.subtitle, 'BTC or sats');
      expect(sheet.options.first.disabledReason, isNull);
    },
  );

  testWidgets('field action text fits increased text scale', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: BullFieldAction(label: 'MAX', onPressed: () {}),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final text = tester.renderObject<RenderParagraph>(find.text('MAX'));
    final target = tester.renderObject<RenderBox>(find.byType(BullFieldAction));
    final natural = Rect.fromLTWH(
      0,
      0,
      text.getMaxIntrinsicWidth(double.infinity),
      text.getMaxIntrinsicHeight(double.infinity),
    );
    final painted = MatrixUtils.transformRect(
      text.getTransformTo(target),
      natural,
    );
    expect(painted.left, greaterThanOrEqualTo(-0.1));
    expect(painted.right, lessThanOrEqualTo(target.size.width + 0.1));
    expect(painted.top, greaterThanOrEqualTo(-0.1));
    expect(painted.bottom, lessThanOrEqualTo(target.size.height + 0.1));
    expect(tester.getSize(find.byType(BullFieldAction)), const Size(48, 48));
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
