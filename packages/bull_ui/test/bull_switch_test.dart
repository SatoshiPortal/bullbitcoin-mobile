import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

/// Every token this widget reads is given a distinct colour, so a test can
/// prove *which* token was used rather than only that the result looks right.
/// The shipped palette maps several of these to the same value, which is how
/// the original swap of `secondary`/`text` went unnoticed.
const _distinct = BullTheme(
  primary: Color(0xFF000001),
  onPrimary: Color(0xFF000002),
  primaryFixed: Color(0xFF000003),
  onPrimaryFixed: Color(0xFF000004),
  secondary: Color(0xFF000005),
  onSecondary: Color(0xFF000006),
  secondaryFixed: Color(0xFF000007),
  secondaryFixedDim: Color(0xFF000008),
  onSecondaryFixed: Color(0xFF000009),
  tertiary: Color(0xFF00000A),
  onTertiary: Color(0xFF00000B),
  tertiaryContainer: Color(0xFF00000C),
  bitcoinOrange: Color(0xFF00000D),
  background: Color(0xFF00000E),
  surface: Color(0xFF00000F),
  surfaceContainer: Color(0xFF000010),
  surfaceContainerHighest: Color(0xFF000011),
  surfaceBright: Color(0xFF000012),
  onSurface: Color(0xFF000013),
  onSurfaceVariant: Color(0xFF000014),
  inverseSurface: Color(0xFF000015),
  cardBackground: Color(0xFF000016),
  text: Color(0xFF000017),
  textMuted: Color(0xFF000018),
  border: Color(0xFF000019),
  outline: Color(0xFF00001A),
  outlineVariant: Color(0xFF00001B),
  error: Color(0xFF00001C),
  onError: Color(0xFF00001D),
  errorContainer: Color(0xFF00001E),
  success: Color(0xFF00001F),
  warning: Color(0xFF000020),
  warningContainer: Color(0xFF000021),
  info: Color(0xFF000022),
  scrim: Color(0xFF000023),
  overlay: Color(0xFF000024),
  transparent: Color(0x00000000),
  surfaceFixed: Color(0xFF000025),
  onSurfaceFixed: Color(0xFF000026),
  shimmerBase: Color(0xFF000027),
  shimmerHighlight: Color(0xFF000028),
);

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(extensions: const [_distinct]),
  home: Scaffold(body: child),
);

void main() {
  group('BullSwitch', () {
    // Regression: the copy was written against surface/text/textMuted/
    // outlineVariant instead of the tokens the original uses, which left every
    // "off" toggle rendering a different colour.
    testWidgets('paints the active state from secondary tokens', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BullSwitch(value: true, onChanged: (_) {})),
      );

      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.activeThumbColor, _distinct.onSecondary);
      expect(sw.activeTrackColor, _distinct.secondary);
    });

    testWidgets('paints the inactive state from border and surfaceContainer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BullSwitch(value: false, onChanged: (_) {})),
      );

      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.inactiveThumbColor, _distinct.border);
      expect(sw.inactiveTrackColor, _distinct.surfaceContainer);
    });

    testWidgets('resolves the track outline from the theme, not a raw colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BullSwitch(value: true, onChanged: (_) {})),
      );

      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(
        sw.trackOutlineColor?.resolve(<WidgetState>{}),
        _distinct.transparent,
      );
    });

    testWidgets('renders disabled when onChanged is null', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const BullSwitch(value: false, onChanged: null)),
      );

      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });
  });
}
