import 'package:bull_ui/app_theme.dart';
import 'package:overview/overview.dart' show EyeToggle;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool? hideAmounts,
  required ValueChanged<bool> onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      home: Scaffold(
        body: Center(
          child: EyeToggle(
            hideAmounts: hideAmounts,
            showLabel: 'Show amounts',
            hideLabel: 'Hide amounts',
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('names the action and offers a 48 dp target', (tester) async {
    final changes = <bool>[];
    await _pump(tester, hideAmounts: null, onChanged: changes.add);
    expect(find.byTooltip('Show amounts'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    final size = tester.getSize(find.byType(EyeToggle));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byTooltip('Show amounts'));
    expect(changes, [false]);
    await _pump(tester, hideAmounts: true, onChanged: changes.add);
    expect(find.byTooltip('Show amounts'), findsOneWidget);
    await _pump(tester, hideAmounts: false, onChanged: changes.add);
    expect(find.byTooltip('Hide amounts'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide amounts'));
    expect(changes, [false, true]);
  });
}
