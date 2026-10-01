import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart'
    show BottomSheet, Builder, ElevatedButton, RoundedRectangleBorder;
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('opens on the app background with 8px bordered top corners', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => ElevatedButton(
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

    expect(find.text('Sheet body'), findsOneWidget);
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.backgroundColor, testBullTheme.background);
    final shape = sheet.shape! as RoundedRectangleBorder;
    expect(
      shape.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(BullRadius.sm)),
    );
    expect(shape.side.color, testBullTheme.secondaryFixedDim);
  });
}
