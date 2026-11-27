import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show EditableText, TextField;

import 'test_app.dart';

void main() {
  group('field', () {
    Widget field({
      String value = '',
      ValueChanged<String>? onChanged,
      VoidCallback? onCleared,
    }) => BullSearchBar(
      hint: 'Search places',
      value: value,
      onChanged: onChanged ?? (_) {},
      onCleared: onCleared ?? () {},
      clearTooltip: 'Clear search',
    );

    testWidgets('reports typing and shows the hint', (tester) async {
      final typed = <String>[];
      await tester.pumpWidget(wrapWithTheme(field(onChanged: typed.add)));

      expect(find.text('Search places'), findsOne);
      await tester.enterText(find.byType(TextField), 'cafe');
      expect(typed, ['cafe']);
    });

    testWidgets('offers clearing only while there is a query', (tester) async {
      var cleared = 0;
      await tester.pumpWidget(wrapWithTheme(field()));
      expect(find.byTooltip('Clear search'), findsNothing);

      await tester.pumpWidget(
        wrapWithTheme(field(value: 'cafe', onCleared: () => cleared++)),
      );
      await tester.tap(find.byTooltip('Clear search'));
      expect(cleared, 1);
    });

    testWidgets('follows a value changed by its owner', (tester) async {
      await tester.pumpWidget(wrapWithTheme(field(value: 'cafe')));
      await tester.pumpWidget(wrapWithTheme(field()));

      final text = tester.widget<TextField>(find.byType(TextField));
      expect(text.controller?.text, isEmpty);
    });
  });

  group('button', () {
    testWidgets('opens search on tap without an editable field', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          BullSearchBar.button(label: 'Search settings', onTap: () => taps++),
        ),
      );

      expect(find.byType(EditableText), findsNothing);
      await tester.tap(find.byType(BullSearchBar));
      expect(taps, 1);
    });

    testWidgets('exposes one enabled button action that opens search', (
      tester,
    ) async {
      var taps = 0;
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          wrapWithTheme(
            BullSearchBar.button(label: 'Search settings', onTap: () => taps++),
          ),
        );

        expect(find.bySemanticsLabel('Search settings'), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(BullSearchBar)),
          matchesSemantics(
            label: 'Search settings',
            isButton: true,
            isFocusable: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );

        tester.semantics.tap(find.semantics.byLabel('Search settings'));
        await tester.pump();
        expect(taps, 1);
      } finally {
        semantics.dispose();
      }
    });
  });
}
