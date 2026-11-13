import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

Widget amount(
  String id, {
  BullAmountUnit unit = BullAmountUnit.sats,
  bool hidden = false,
}) => BullAmount(
  key: ValueKey(id),
  satsText: hidden ? '** sats' : '12,345 sats',
  btcText: hidden ? '** BTC' : '0.00012345 BTC',
  defaultUnit: unit,
  switchToBtcLabel: 'Show in BTC',
  switchToSatsLabel: 'Show in sats',
);

void main() {
  testWidgets('tap toggles only one amount and consumes parent navigation', (
    tester,
  ) async {
    var navigations = 0;
    await tester.pumpWidget(
      wrapWithTheme(
        InkWell(
          onTap: () => navigations++,
          child: Column(
            children: [amount('a'), amount('b'), const Text('Open details')],
          ),
        ),
      ),
    );
    await tester.tap(find.text('12,345 sats').first);
    await tester.pump();
    expect(find.text('0.00012345 BTC'), findsOneWidget);
    expect(find.text('12,345 sats'), findsOneWidget);
    expect(navigations, 0);
    await tester.tap(find.text('Open details'));
    expect(navigations, 1);
  });

  testWidgets(
    'untouched follows default, override survives rebuild and keyed reorder',
    (tester) async {
      Widget host(BullAmountUnit unit, bool reversed) => wrapWithTheme(
        Column(
          children: reversed
              ? [amount('b', unit: unit), amount('a', unit: unit)]
              : [amount('a', unit: unit), amount('b', unit: unit)],
        ),
      );
      await tester.pumpWidget(host(BullAmountUnit.sats, false));
      await tester.tap(find.text('12,345 sats').first);
      await tester.pumpWidget(host(BullAmountUnit.btc, true));
      expect(find.text('0.00012345 BTC'), findsNWidgets(2));
      await tester.pumpWidget(host(BullAmountUnit.sats, true));
      expect(find.text('12,345 sats'), findsOneWidget);
      expect(find.text('0.00012345 BTC'), findsOneWidget);
      final first = find.byType(BullAmount).first;
      expect(tester.widget<BullAmount>(first).key, const ValueKey('b'));
      expect(
        find.descendant(of: first, matching: find.text('12,345 sats')),
        findsOneWidget,
      );
      await tester.pumpWidget(wrapWithTheme(const SizedBox()));
      await tester.pumpWidget(host(BullAmountUnit.sats, false));
      expect(find.text('12,345 sats'), findsNWidgets(2));
    },
  );

  testWidgets('semantics value changes without exposing a masked amount', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrapWithTheme(amount('private', hidden: true)));
    expect(find.bySemanticsLabel('Show in BTC'), findsOneWidget);
    final node = tester.getSemantics(find.byType(BullAmountUnitToggle));
    expect(node.value, '** sats');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    await tester.tap(find.text('** sats'));
    await tester.pump();
    expect(
      tester.getSemantics(find.byType(BullAmountUnitToggle)).value,
      '** BTC',
    );
    expect(find.textContaining('12345'), findsNothing);
    expect(find.byTooltip('Show in sats'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    '48 dp target survives narrow layout and large text, keyboard activates',
    (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SizedBox(width: 180, child: amount('a')),
          ),
        ),
      );
      final size = tester.getSize(find.byType(TextButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('0.00012345 BTC'), findsOneWidget);
    },
  );
}
