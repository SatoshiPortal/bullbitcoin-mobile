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

  testWidgets('keys preserve local choices until any global default change', (
    tester,
  ) async {
    Widget host(BullAmountUnit unit, bool reversed) => wrapWithTheme(
      Column(
        children: reversed
            ? [amount('b', unit: unit), amount('a', unit: unit)]
            : [amount('a', unit: unit), amount('b', unit: unit)],
      ),
    );
    await tester.pumpWidget(host(BullAmountUnit.sats, false));
    await tester.tap(find.text('12,345 sats').first);
    await tester.pumpWidget(host(BullAmountUnit.sats, true));
    expect(find.text('0.00012345 BTC'), findsOneWidget);
    final first = find.byType(BullAmount).first;
    expect(tester.widget<BullAmount>(first).key, const ValueKey('b'));
    expect(
      find.descendant(of: first, matching: find.text('12,345 sats')),
      findsOneWidget,
    );
    await tester.pumpWidget(host(BullAmountUnit.btc, true));
    expect(find.text('0.00012345 BTC'), findsNWidgets(2));
    await tester.pumpWidget(host(BullAmountUnit.sats, true));
    expect(find.text('12,345 sats'), findsNWidgets(2));
    await tester.pumpWidget(wrapWithTheme(const SizedBox()));
    await tester.pumpWidget(host(BullAmountUnit.sats, false));
    expect(find.text('12,345 sats'), findsNWidgets(2));
  });

  testWidgets('long press invokes global action without toggling locally', (
    tester,
  ) async {
    var longPresses = 0;
    await tester.pumpWidget(
      wrapWithTheme(
        BullAmount(
          satsText: '12 sats',
          btcText: '0.00000012 BTC',
          defaultUnit: BullAmountUnit.sats,
          switchToBtcLabel: 'Show in BTC',
          switchToSatsLabel: 'Show in sats',
          onLongPress: () => longPresses++,
          longPressLabel: 'Change default unit',
          tooltip: 'Tap to switch; hold to change default',
        ),
      ),
    );
    expect(
      find.byTooltip('Tap to switch; hold to change default'),
      findsOneWidget,
    );
    await tester.longPress(find.text('12 sats'));
    await tester.pump();
    expect(longPresses, 1);
    expect(find.text('12 sats'), findsOneWidget);
    expect(find.text('0.00000012 BTC'), findsNothing);
  });

  testWidgets('named accessibility action invokes long press callback', (
    tester,
  ) async {
    var taps = 0;
    var longPresses = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrapWithTheme(
        BullAmountUnitToggle(
          text: '12 sats',
          actionLabel: 'Show in BTC',
          onPressed: () => taps++,
          onLongPress: () => longPresses++,
          longPressLabel: 'Change default unit',
        ),
      ),
    );
    final node = tester.getSemantics(find.byType(BullAmountUnitToggle));
    const action = CustomSemanticsAction(label: 'Change default unit');
    final id = CustomSemanticsAction.getIdentifier(action);
    expect(node.getSemanticsData().customSemanticsActionIds, contains(id));
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.longPress),
      isTrue,
    );
    tester.binding.renderViews.first.owner?.semanticsOwner?.performAction(
      node.id,
      SemanticsAction.customAction,
      id,
    );
    await tester.pump();
    expect(longPresses, 1);
    expect(taps, 0);
    semantics.dispose();
  });

  testWidgets(
    'global long press persists and Undo restores the previous default',
    (tester) async {
      var defaultUnit = BullAmountUnit.sats;
      final writes = <BullAmountUnit>[];
      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) => BullAmountPreferencesScope(
              preferences: BullAmountPreferences(
                defaultUnit: defaultUnit,
                changeDefaultUnit: (unit) async {
                  writes.add(unit);
                  setState(() => defaultUnit = unit);
                  return true;
                },
                globalActionLabel: 'Change default everywhere',
                tooltip: 'Tap locally; hold globally',
                satsEverywhereMessage: 'Everywhere in sats',
                btcEverywhereMessage: 'Everywhere in BTC',
                undoLabel: 'Undo',
                failureMessage: 'Could not change default',
              ),
              child: BullAmount(
                satsText: '12 sats',
                btcText: '0.00000012 BTC',
                defaultUnit: defaultUnit,
                switchToBtcLabel: 'Show in BTC',
                switchToSatsLabel: 'Show in sats',
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('12 sats'));
      await tester.pump();
      expect(defaultUnit, BullAmountUnit.sats);
      expect(writes, isEmpty);
      await tester.tap(find.text('0.00000012 BTC'));
      await tester.pump();
      await tester.longPress(find.text('12 sats'));
      await tester.pumpAndSettle();
      expect(defaultUnit, BullAmountUnit.btc);
      expect(writes, [BullAmountUnit.btc]);
      expect(find.text('Everywhere in BTC'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(defaultUnit, BullAmountUnit.sats);
      expect(writes, [BullAmountUnit.btc, BullAmountUnit.sats]);
      BullSnackBar.dismiss();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'long press chooses opposite displayed unit and clears all local overrides even for the same default',
    (tester) async {
      final writes = <BullAmountUnit>[];
      await tester.pumpWidget(
        wrapWithTheme(
          BullAmountPreferencesScope(
            preferences: BullAmountPreferences(
              defaultUnit: BullAmountUnit.sats,
              changeDefaultUnit: (unit) async {
                writes.add(unit);
                return true;
              },
              globalActionLabel: 'Change default everywhere',
              tooltip: 'Tap or hold',
              satsEverywhereMessage: 'Everywhere in sats',
              btcEverywhereMessage: 'Everywhere in BTC',
              undoLabel: 'Undo',
              failureMessage: 'Failed',
            ),
            child: Column(children: [amount('a'), amount('b')]),
          ),
        ),
      );
      await tester.tap(find.text('12,345 sats').first);
      await tester.pump();
      await tester.tap(find.text('12,345 sats'));
      await tester.pump();
      expect(find.text('0.00012345 BTC'), findsNWidgets(2));
      await tester.longPress(find.text('0.00012345 BTC').first);
      await tester.pumpAndSettle();
      expect(writes, [BullAmountUnit.sats]);
      expect(find.text('Everywhere in sats'), findsOneWidget);
      expect(find.text('12,345 sats'), findsNWidgets(2));
      await tester.tap(find.text('12,345 sats').first);
      await tester.pump();
      expect(find.text('0.00012345 BTC'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(writes, [BullAmountUnit.sats, BullAmountUnit.sats]);
      expect(find.text('12,345 sats'), findsNWidgets(2));
      BullSnackBar.dismiss();
      await tester.pumpAndSettle();
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
