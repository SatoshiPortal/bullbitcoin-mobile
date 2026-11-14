import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullShapes.standard', () {
    test('holds Bull\'s radii', () {
      const s = BullShapes.standard;
      expect(s.button, 2);
      expect(s.key, 6);
      expect(s.card, 2);
      expect(s.input, 4);
      expect(s.checkbox, 2);
      expect(s.badge, 2);
      expect(s.chip, 2);
      expect(s.sheet, 8);
      expect(s.dot, 999);
    });
  });

  group('copyWith', () {
    test('replaces only the given roles', () {
      final s = BullShapes.standard.copyWith(button: 999, card: 8);
      expect(s.button, 999);
      expect(s.card, 8);
      expect(s.badge, BullShapes.standard.badge);
      expect(s.sheet, BullShapes.standard.sheet);
    });
  });

  group('lerp', () {
    const a = BullShapes.standard;
    final b = a.copyWith(button: 12, sheet: 24);

    test('interpolates every role', () {
      final mid = a.lerp(b, 0.5);
      expect(mid.button, 7);
      expect(mid.sheet, 16);
      expect(mid.card, a.card);
    });

    test('returns the endpoints at 0 and 1', () {
      expect(a.lerp(b, 0).button, a.button);
      expect(a.lerp(b, 1).button, b.button);
    });

    test('returns itself when the other side is missing', () {
      expect(a.lerp(null, 0.5), same(a));
    });
  });

  group('context.bullShapes', () {
    testWidgets('reads the registered shapes', (tester) async {
      late BullShapes shapes;
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) {
              shapes = context.bullShapes;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(shapes, same(BullShapes.standard));
    });

    testWidgets('throws a StateError when none is registered', (tester) async {
      Object? error;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [testBullTheme]),
          home: Builder(
            builder: (context) {
              try {
                context.bullShapes;
              } on StateError catch (e) {
                error = e;
              }
              return const SizedBox();
            },
          ),
        ),
      );
      expect(error, isA<StateError>());
      expect('$error', contains('BullShapes'));
    });
  });
}
