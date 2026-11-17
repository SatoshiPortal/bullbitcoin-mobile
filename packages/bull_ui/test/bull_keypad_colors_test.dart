import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

/// WCAG 2 contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('BullKeypadColors', () {
    final pairs = <String, (Color, Color) Function(BullKeypadColors)>{
      'onKey on key': (c) => (c.onKey, c.key),
      'key on panel': (c) => (c.key, c.panel),
      'functionKey on panel': (c) => (c.functionKey, c.panel),
      'onFunctionKey on functionKey': (c) => (c.onFunctionKey, c.functionKey),
      'onFunctionKeyDisabled on functionKey': (c) =>
          (c.onFunctionKeyDisabled, c.functionKey),
      'disabledGlyph on panel': (c) => (c.disabledGlyph, c.panel),
    };

    for (final MapEntry(key: name, value: pair) in pairs.entries) {
      test('$name reads with the same contrast in both themes', () {
        final (lightFg, lightBg) = pair(BullKeypadColors.light);
        final (darkFg, darkBg) = pair(BullKeypadColors.dark);
        expect(
          contrast(lightFg, lightBg),
          closeTo(contrast(darkFg, darkBg), 0.05),
        );
      });
    }

    test('of picks the preset for the brightness', () {
      expect(BullKeypadColors.of(Brightness.light), BullKeypadColors.light);
      expect(BullKeypadColors.of(Brightness.dark), BullKeypadColors.dark);
    });

    test('copyWith replaces only the given roles', () {
      const red = Color(0xFFFF0000);
      final c = BullKeypadColors.dark.copyWith(panel: red);
      expect(c.panel, red);
      expect(c.key, BullKeypadColors.dark.key);
      expect(c.disabledGlyph, BullKeypadColors.dark.disabledGlyph);
    });

    test('lerp returns the endpoints and itself without another side', () {
      const a = BullKeypadColors.light;
      const b = BullKeypadColors.dark;
      expect(a.lerp(b, 0).panel, a.panel);
      expect(a.lerp(b, 1).panel, b.panel);
      expect(a.lerp(null, 0.5), same(a));
    });

    testWidgets('context.bullKeypad reads the registered colours', (
      tester,
    ) async {
      late BullKeypadColors keypad;
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) {
              keypad = context.bullKeypad;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(keypad, same(BullKeypadColors.light));
    });

    testWidgets('context.bullKeypad throws when none is registered', (
      tester,
    ) async {
      Object? error;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [testBullTheme]),
          home: Builder(
            builder: (context) {
              try {
                context.bullKeypad;
              } on StateError catch (e) {
                error = e;
              }
              return const SizedBox();
            },
          ),
        ),
      );
      expect(error, isA<StateError>());
      expect('$error', contains('BullKeypadColors'));
    });
  });
}
