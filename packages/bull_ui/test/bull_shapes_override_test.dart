import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

/// Radii that all differ from [BullShapes.standard], so a widget that ignores the registered shapes fails.
final customShapes = BullShapes.standard.copyWith(
  button: 999,
  input: 12,
  sheet: 24,
);

Widget wrapWithCustomShapes(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: [testBullTheme, customShapes]),
    home: Scaffold(body: child),
  );
}

void main() {
  group('custom BullShapes restyle', () {
    testWidgets('BullButton with the button role', (tester) async {
      await tester.pumpWidget(
        wrapWithCustomShapes(
          BullButton.big(
            label: 'Send',
            onPressed: () {},
            bgColor: testBullTheme.primary,
            textColor: testBullTheme.onPrimary,
          ),
        ),
      );

      final expected = BorderRadius.circular(customShapes.button);
      final inkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(BullButton),
          matching: find.byType(InkWell),
        ),
      );
      expect(inkWell.borderRadius, expected);

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(InkWell),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration;
      expect(decoration, isA<BoxDecoration>());
      if (decoration is BoxDecoration) {
        expect(decoration.borderRadius, expected);
      }
    });

    testWidgets('BullInputText with the input role', (tester) async {
      await tester.pumpWidget(
        wrapWithCustomShapes(BullInputText(value: '', onChanged: (_) {})),
      );

      final border = tester
          .widget<TextField>(find.byType(TextField))
          .decoration
          ?.enabledBorder;
      expect(border, isA<OutlineInputBorder>());
      if (border is OutlineInputBorder) {
        expect(border.borderRadius, BorderRadius.circular(customShapes.input));
      }
    });

    testWidgets('BullBottomSheet with the sheet role', (tester) async {
      await tester.pumpWidget(
        wrapWithCustomShapes(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => BullBottomSheet.show<void>(
                context: context,
                child: const Text('Sheet body'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final shape = tester.widget<BottomSheet>(find.byType(BottomSheet)).shape;
      expect(shape, isA<RoundedRectangleBorder>());
      if (shape is RoundedRectangleBorder) {
        expect(
          shape.borderRadius,
          BorderRadius.vertical(top: Radius.circular(customShapes.sheet)),
        );
      }
    });
  });
}
