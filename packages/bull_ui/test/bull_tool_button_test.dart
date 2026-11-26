import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  Widget app({
    required VoidCallback first,
    VoidCallback? second,
    bool disabled = false,
  }) => wrapWithTheme(
    Column(
      children: [
        BullToolButton(
          label: 'First',
          icon: BullIcons.close,
          onPressed: first,
          disabled: disabled,
        ),
        BullToolButton(
          label: 'Second',
          icon: BullIcons.close,
          onPressed: second ?? () {},
        ),
      ],
    ),
  );

  testWidgets('is reached with Tab and activated with Enter and Space', (
    tester,
  ) async {
    var first = 0;
    var second = 0;
    await tester.pumpWidget(app(first: () => first++, second: () => second++));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect((first, second), (1, 0));

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect((first, second), (2, 0));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect((first, second), (2, 1));
  });

  testWidgets('still activates on tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(first: () => taps++));
    await tester.tap(find.text('First'));
    expect(taps, 1);
  });

  testWidgets('a disabled button is skipped by Tab and ignores keys', (
    tester,
  ) async {
    var first = 0;
    var second = 0;
    await tester.pumpWidget(
      app(first: () => first++, second: () => second++, disabled: true),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect((first, second), (0, 1));
  });

  testWidgets('exposes one focusable button node named by its label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(first: () {}));

    expect(find.bySemanticsLabel('First'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('First')),
      matchesSemantics(
        label: 'First',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });
}
