import 'dart:ui' show SemanticsAction;

import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('default table keeps its themed dividers and 2 to 3 columns', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const BullDetailsTable(
          items: [
            BullDetailsTableItem(label: 'Amount', displayValue: '100 sats'),
            BullDetailsTableItem(label: 'Fee', displayValue: '1 sat'),
          ],
        ),
      ),
    );
    final first = find.byType(BullDetailsTableItem).first;
    final columns = tester.widgetList<Expanded>(
      find.descendant(of: first, matching: find.byType(Expanded)),
    );
    expect(columns.map((column) => column.flex), [2, 3]);
    expect(tester.widget<Divider>(find.byType(Divider)).height, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy Expand does not require MaterialLocalizations', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(extensions: testBullExtensions),
          child: const Material(
            child: BullDetailsTableItem(
              label: 'Details',
              displayValue: 'key',
              copyValue: 'public',
              expandableChild: Text('Legacy body'),
            ),
          ),
        ),
      ),
    );
    expect(
      Localizations.of<MaterialLocalizations>(
        tester.element(find.byType(BullDetailsTableItem)),
        MaterialLocalizations,
      ),
      isNull,
    );
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(find.text('Legacy body'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();
    expect(find.text('Legacy body'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact copy and expand have named actionable 48dp nodes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final writes = <Object?>[];
    var copied = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') writes.add(call.arguments);
        return null;
      },
    );
    try {
      await tester.pumpWidget(
        wrapWithTheme(
          BullDetailsTable(
            flat: true,
            dividerHeight: 1,
            items: [
              BullDetailsTableItem(
                compact: true,
                label: 'Public key',
                displayValue: 'key',
                copyValue: 'the-exact-full-public-value',
                onCopied: () => copied++,
                expandableChild: const Text('Full details'),
              ),
              const BullDetailsTableItem(
                compact: true,
                label: 'Fee',
                displayValue: '1 sat',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final item = find.byType(BullDetailsTableItem).first;
      expect(tester.getSize(item).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .widgetList<Expanded>(
              find.descendant(of: item, matching: find.byType(Expanded)),
            )
            .map((column) => column.flex),
        [3, 2],
      );
      expect(tester.widget<Divider>(find.byType(Divider)).height, 1);
      final copy = find.bySemanticsLabel('Copy');
      expect(copy, findsOneWidget);
      final copyData = tester.getSemantics(copy).getSemanticsData();
      expect(copyData.hasAction(SemanticsAction.tap), true);
      expect(copyData.flagsCollection.isButton, true);
      final bounds = tester.getRect(copy);
      expect(bounds.width, greaterThanOrEqualTo(48));
      expect(bounds.height, greaterThanOrEqualTo(48));
      await tester.tapAt(bounds.centerLeft + const Offset(1, 0));
      await tester.pump();
      expect(writes, [
        {'text': 'the-exact-full-public-value'},
      ]);
      expect(copied, 1);
      final expand = find.bySemanticsLabel('Expand');
      expect(
        tester
            .getSemantics(expand)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        true,
      );
      expect(
        tester
            .getSemantics(expand)
            .getSemanticsData()
            .flagsCollection
            .isExpanded
            .toBoolOrNull(),
        false,
      );
      final expandBounds = tester.getRect(expand);
      expect(expandBounds.width, greaterThanOrEqualTo(48));
      expect(expandBounds.height, greaterThanOrEqualTo(48));
      await tester.tapAt(expandBounds.centerRight - const Offset(1, 0));
      await tester.pumpAndSettle();
      expect(find.text('Full details'), findsOneWidget);
      final collapse = find.bySemanticsLabel('Collapse');
      expect(
        tester
            .getSemantics(collapse)
            .getSemanticsData()
            .flagsCollection
            .isExpanded
            .toBoolOrNull(),
        true,
      );
      expect(
        tester
            .getSemantics(collapse)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        true,
      );
      await tester.tap(collapse);
      await tester.pumpAndSettle();
      expect(find.text('Full details'), findsNothing);
      expect(copied, 1);
      expect(tester.takeException(), isNull);
    } finally {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      semantics.dispose();
    }
  });

  testWidgets('compact rows grow for long labels and enlarged text', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: const SizedBox(
              width: 330,
              child: BullDetailsTable(
                flat: true,
                dividerHeight: 1,
                items: [
                  BullDetailsTableItem(
                    compact: true,
                    label: 'Montant minimum du dépôt sur le serveur',
                    displayValue: '100 000 sats',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(BullDetailsTableItem)).height,
      greaterThan(48),
    );
    expect(tester.takeException(), isNull);
  });
}
