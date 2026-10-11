import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullDropdown', () {
    testWidgets('reports the tapped item to onChanged', (tester) async {
      String? selected = 'a';
      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              return BullDropdown<String>(
                value: selected,
                onChanged: (v) => setState(() => selected = v),
                items: const [
                  DropdownMenuItem(value: 'a', child: Text('Apple')),
                  DropdownMenuItem(value: 'b', child: Text('Banana')),
                ],
              );
            },
          ),
        ),
      );

      // Open the menu (the closed field shows the current selection).
      await tester.tap(find.text('Apple').last);
      await tester.pumpAndSettle();

      // Tap the other option in the open menu.
      await tester.tap(find.text('Banana').last);
      await tester.pumpAndSettle();

      expect(selected, 'b');
    });
  });
  testWidgets('multiline options determine the field height', (tester) async {
    const label = 'Contents fetched from the backup server';
    await tester.pumpWidget(
      wrapWithTheme(
        Center(
          child: SizedBox(
            width: 240,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: BullDropdown<bool>(
                height: null,
                value: true,
                items: const [
                  DropdownMenuItem(value: true, child: Text(label)),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(BullDropdown<bool>)).height,
      greaterThan(64),
    );
    expect(
      tester
          .getRect(find.byType(BullDropdown<bool>))
          .contains(tester.getBottomRight(find.text(label))),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
