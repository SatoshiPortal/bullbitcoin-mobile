import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/widgets.dart' show Directionality;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final selected in [null, DateTime.utc(2021, 3)]) {
    testWidgets(
      'year menu opens with ${selected?.year ?? 'newest year'} visible',
      (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            BullMonthPicker(
              value: selected,
              now: DateTime.utc(2026, 10, 28),
              earliest: DateTime.utc(2009, 1),
              monthLabel: 'Month',
              yearLabel: 'Year',
              monthName: (date) => '${date.month}',
              onChanged: (_) {},
            ),
          ),
        );
        final year = find.byType(BullDropdown<int>).first;
        final items = tester.widget<BullDropdown<int>>(year).items;
        expect(items.map((item) => item.value), [
          for (var y = 2026; y >= 2009; y--) y,
        ]);
        await tester.tap(year);
        await tester.pumpAndSettle();
        final visibleYear = selected?.year ?? 2026;
        expect(find.text('$visibleYear').last.hitTestable(), findsOneWidget);
        if (selected == null) {
          expect(find.text('2025').last.hitTestable(), findsOneWidget);
          expect(
            tester.getTopLeft(find.text('2026').last).dy,
            lessThan(tester.getTopLeft(find.text('2025').last).dy),
          );
        }
        await tester.tap(find.text('$visibleYear').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('RTL month and year values align to the reading start', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Directionality(
          textDirection: TextDirection.rtl,
          child: BullMonthPicker(
            value: DateTime.utc(2026, 10),
            now: DateTime.utc(2026, 10, 28),
            earliest: DateTime.utc(2009, 1),
            monthLabel: 'الشهر',
            yearLabel: 'السنة',
            monthName: (_) => 'أكتوبر',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    final fields = find.byType(BullDropdown<int>);
    for (final (field, value) in [
      (fields.first, '2026'),
      (fields.last, 'أكتوبر'),
    ]) {
      final selected = find.descendant(of: field, matching: find.text(value));
      expect(
        tester.getCenter(selected.first).dx,
        greaterThan(tester.getCenter(field).dx),
      );
    }
  });

  testWidgets(
    'months are newest first, capped at now; year change clamps the selected month',
    (tester) async {
      DateTime? selected;
      await tester.pumpWidget(
        wrapWithTheme(
          BullMonthPicker(
            value: DateTime.utc(2025, 12),
            now: DateTime.utc(2026, 10, 28),
            earliest: DateTime.utc(2017, 8),
            monthLabel: 'Month',
            yearLabel: 'Year',
            monthName: (date) => '${date.month}',
            onChanged: (date) => selected = date,
          ),
        ),
      );
      final fields = tester
          .widgetList<BullDropdown<int>>(find.byType(BullDropdown<int>))
          .toList();
      expect(fields.first.items.first.value, 2026);
      expect(fields.last.items.first.value, 12);
      fields.first.onChanged?.call(2026);
      expect(selected, DateTime.utc(2026, 10));
      await tester.pumpWidget(
        wrapWithTheme(
          BullMonthPicker(
            value: DateTime.utc(2026, 10),
            now: DateTime.utc(2026, 10, 28),
            latest: DateTime.utc(2027),
            earliest: DateTime.utc(2017, 8),
            monthLabel: 'Month',
            yearLabel: 'Year',
            monthName: (date) => '${date.month}',
            onChanged: (_) {},
          ),
        ),
      );
      final months = tester
          .widgetList<BullDropdown<int>>(find.byType(BullDropdown<int>))
          .last
          .items;
      expect(months.map((item) => item.value), [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]);
    },
  );
}
