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
  });
}
