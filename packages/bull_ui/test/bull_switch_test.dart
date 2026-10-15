import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullSwitch', () {
    Switch pumpedSwitch(WidgetTester tester) =>
        tester.widget<Switch>(find.byType(Switch));

    testWidgets('uses the app-wide switch colours', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(BullSwitch(value: false, onChanged: (_) {})),
      );

      final s = pumpedSwitch(tester);
      expect(s.activeThumbColor, testBullTheme.surface);
      expect(s.activeTrackColor, testBullTheme.text);
      expect(s.inactiveThumbColor, testBullTheme.surface);
      expect(s.inactiveTrackColor, testBullTheme.textMuted);
    });

    testWidgets('keeps the off track distinct from tinted rows', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(BullSwitch(value: false, onChanged: (_) {})),
      );

      // The receive payjoin row sits on surfaceContainerHighest; an off track
      // of the same colour made the track vanish into the row.
      expect(
        pumpedSwitch(tester).inactiveTrackColor,
        isNot(testBullTheme.surfaceContainerHighest),
      );
    });

    testWidgets('resolves the track outline from the theme, not a raw colour', (
      tester,
    ) async {
      // A transparent token that differs from Colors.transparent, so a
      // hardcoded colour would fail here instead of matching by coincidence.
      final theme = testBullTheme.copyWith(
        transparent: const Color(0x00ABCDEF),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [theme]),
          home: Scaffold(body: BullSwitch(value: true, onChanged: (_) {})),
        ),
      );

      expect(
        pumpedSwitch(tester).trackOutlineColor?.resolve(<WidgetState>{}),
        theme.transparent,
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

      expect(pumpedSwitch(tester).onChanged, isNull);
    });

    testWidgets('explains a disabled switch when tapped without toggling it', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          BullSwitch(
            value: false,
            onChanged: null,
            onDisabledTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(taps, 1);
      expect(pumpedSwitch(tester).value, isFalse);
      expect(pumpedSwitch(tester).onChanged, isNull);
    });

    testWidgets('does not explain a switch that can be toggled', (
      tester,
    ) async {
      var taps = 0;
      bool? changed;
      await tester.pumpWidget(
        wrapWithTheme(
          BullSwitch(
            value: false,
            onChanged: (value) => changed = value,
            onDisabledTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(changed, isTrue);
      expect(taps, 0);
    });
  });
}
