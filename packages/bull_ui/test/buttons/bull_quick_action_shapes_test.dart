import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shortcut surface and ink follow the injected button shape', (
    tester,
  ) async {
    final shapes = BullShapes.standard.copyWith(button: 9);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [testBullTheme, shapes]),
        home: Scaffold(
          body: BullQuickAction(
            label: 'Transfer',
            icon: BullIcons.swapHoriz,
            onPressed: () {},
          ),
        ),
      ),
    );
    final action = find.byType(BullQuickAction);
    final material = tester.widget<Material>(
      find.descendant(of: action, matching: find.byType(Material)),
    );
    final ink = tester.widget<InkWell>(
      find.descendant(of: action, matching: find.byType(InkWell)),
    );
    expect(material.borderRadius, BorderRadius.circular(shapes.button));
    expect(ink.borderRadius, material.borderRadius);
  });
}
