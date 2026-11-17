import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullSwitch', () {
    const on = {WidgetState.selected};
    const off = <WidgetState>{};
    final theme = BullSwitch.themeData(testBullTheme);

    SwitchThemeData appliedTheme(WidgetTester tester) =>
        SwitchTheme.of(tester.element(find.byType(Switch)));

    test('off is a hollow outlined track with a grey thumb and a cross', () {
      expect(theme.trackColor?.resolve(off), testBullTheme.transparent);
      expect(theme.trackOutlineColor?.resolve(off), testBullTheme.outline);
      expect(theme.trackOutlineWidth?.resolve(off), 2);
      expect(theme.thumbColor?.resolve(off), testBullTheme.textMuted);
      expect(theme.thumbIcon?.resolve(off)?.icon, Icons.close);
    });

    test('on is a primary track with a white thumb and a check', () {
      expect(theme.trackColor?.resolve(on), testBullTheme.primary);
      expect(theme.thumbColor?.resolve(on), testBullTheme.onPrimary);
      final icon = theme.thumbIcon?.resolve(on);
      expect(icon?.icon, Icons.check);
      expect(icon?.color, testBullTheme.primary);
    });

    test('a disabled switch keeps its look, faded', () {
      final disabled = {WidgetState.selected, WidgetState.disabled};
      expect(
        theme.trackColor?.resolve(disabled),
        testBullTheme.primary.withValues(alpha: 0.38),
      );
      expect(theme.thumbIcon?.resolve(disabled)?.icon, Icons.check);
    });

    testWidgets('draws with its own theme whatever the app theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(BullSwitch(value: false, onChanged: (_) {})),
      );
      expect(appliedTheme(tester).thumbIcon?.resolve(off)?.icon, Icons.close);
      expect(
        appliedTheme(tester).trackOutlineColor?.resolve(off),
        testBullTheme.outline,
      );
    });

    testWidgets('reports toggles via onChanged', (tester) async {
      bool? changed;
      await tester.pumpWidget(
        wrapWithTheme(BullSwitch(value: false, onChanged: (v) => changed = v)),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(changed, isTrue);
    });

    testWidgets('renders disabled when onChanged is null', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const BullSwitch(value: true, onChanged: null)),
      );

      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });
  });
}
