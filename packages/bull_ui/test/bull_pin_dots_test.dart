import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

Future<void> pumpDots(
  WidgetTester tester, {
  required String value,
  bool obscure = true,
  VoidCallback? onToggle,
}) {
  return tester.pumpWidget(
    wrapWithTheme(
      BullPinDots(
        value: value,
        obscure: obscure,
        onToggleObscure: onToggle ?? () {},
        showLabel: 'Show PIN',
        hideLabel: 'Hide PIN',
        hint: 'Enter 4 to 8 digits',
        semanticLabel: 'PIN',
      ),
    ),
  );
}

void main() {
  testWidgets('shows one dot per digit typed, none before', (tester) async {
    Finder dots() => find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle,
    );
    await pumpDots(tester, value: '');
    expect(dots(), findsNothing);
    await pumpDots(tester, value: '12');
    expect(dots(), findsNWidgets(2));
    await pumpDots(tester, value: '12345678');
    expect(dots(), findsNWidgets(8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides the digits until shown, and the toggle reports taps', (
    tester,
  ) async {
    var toggles = 0;
    await pumpDots(tester, value: '1234', onToggle: () => toggles++);
    expect(find.text('1'), findsNothing);
    expect(find.text('Enter 4 to 8 digits'), findsOneWidget);
    expect(find.byTooltip('Show PIN'), findsOneWidget);
    await tester.tap(find.byTooltip('Show PIN'));
    expect(toggles, 1);
    await pumpDots(tester, value: '1234', obscure: false);
    expect(find.text('1'), findsOneWidget);
    expect(find.byTooltip('Hide PIN'), findsOneWidget);
  });

  testWidgets('the eye is crossed while the digits are hidden', (tester) async {
    await pumpDots(tester, value: '1234');
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    await pumpDots(tester, value: '1234', obscure: false);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
  });

  testWidgets('shown digits stay out of the semantics tree', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpDots(tester, value: '1234', obscure: false);
      expect(find.bySemanticsLabel('PIN'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('1')), findsNothing);
    } finally {
      semantics.dispose();
    }
  });
}
