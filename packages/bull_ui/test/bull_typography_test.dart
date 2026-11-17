import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

void main() {
  group('BullTypography.standard', () {
    const t = BullTypography.standard;

    test('holds Bull\'s size, line height and weight per role', () {
      void expectRole(
        TextStyle style,
        double size,
        double lineHeight,
        FontWeight weight,
      ) {
        expect(style.fontFamily, 'Golos Text');
        expect(style.fontSize, size);
        expect(style.height, lineHeight / size);
        expect(style.fontWeight, weight);
      }

      expectRole(t.display, 45, 52, FontWeight.w500);
      expectRole(t.headline, 28, 36, FontWeight.w500);
      expectRole(t.title, 22, 28, FontWeight.w500);
      expectRole(t.subtitle, 18, 24, FontWeight.w500);
      expectRole(t.body, 16, 24, FontWeight.w400);
      expectRole(t.label, 14, 20, FontWeight.w500);
      expectRole(t.caption, 12, 16, FontWeight.w400);
    });

    test('no role is smaller than 12', () {
      for (final role in BullTextRole.values) {
        expect(t.of(role).fontSize, greaterThanOrEqualTo(12), reason: '$role');
      }
    });

    test('uses only the weights the font ships', () {
      for (final role in BullTextRole.values) {
        expect(
          t.of(role).fontWeight,
          isIn([FontWeight.w400, FontWeight.w500, FontWeight.w700]),
          reason: '$role',
        );
      }
    });

    test('of maps each role to its style', () {
      expect(t.of(BullTextRole.display), t.display);
      expect(t.of(BullTextRole.headline), t.headline);
      expect(t.of(BullTextRole.title), t.title);
      expect(t.of(BullTextRole.subtitle), t.subtitle);
      expect(t.of(BullTextRole.body), t.body);
      expect(t.of(BullTextRole.label), t.label);
      expect(t.of(BullTextRole.caption), t.caption);
    });
  });

  group('toTextTheme', () {
    const t = BullTypography.standard;
    final theme = t.toTextTheme();

    void expectSlot(TextStyle? slot, TextStyle role, FontWeight weight) {
      expect(slot, isNotNull);
      expect(slot?.fontFamily, BullTypography.fontFamily);
      expect(slot?.fontSize, role.fontSize);
      expect(slot?.height, role.height);
      expect(slot?.fontWeight, weight);
    }

    test('fills every Material slot from a role', () {
      expectSlot(theme.displayLarge, t.display, FontWeight.w500);
      expectSlot(theme.displayMedium, t.display, FontWeight.w500);
      expectSlot(theme.displaySmall, t.headline, FontWeight.w500);
      expectSlot(theme.headlineLarge, t.subtitle, FontWeight.w700);
      expectSlot(theme.headlineMedium, t.subtitle, FontWeight.w500);
      expectSlot(theme.headlineSmall, t.subtitle, FontWeight.w400);
      expectSlot(theme.titleLarge, t.title, FontWeight.w500);
      expectSlot(theme.titleMedium, t.body, FontWeight.w500);
      expectSlot(theme.titleSmall, t.label, FontWeight.w500);
      expectSlot(theme.bodyLarge, t.body, FontWeight.w500);
      expectSlot(theme.bodyMedium, t.body, FontWeight.w400);
      expectSlot(theme.bodySmall, t.label, FontWeight.w400);
      expectSlot(theme.labelLarge, t.label, FontWeight.w500);
      expectSlot(theme.labelMedium, t.caption, FontWeight.w400);
      expectSlot(theme.labelSmall, t.caption, FontWeight.w400);
    });

    test('follows an overridden role', () {
      final custom = t.copyWith(body: t.body.copyWith(fontSize: 17));
      expect(custom.toTextTheme().bodyMedium?.fontSize, 17);
    });
  });

  group('copyWith', () {
    test('replaces only the given roles', () {
      const big = TextStyle(fontSize: 40);
      final t = BullTypography.standard.copyWith(body: big);
      expect(t.body, big);
      expect(t.caption, BullTypography.standard.caption);
      expect(t.display, BullTypography.standard.display);
    });
  });

  group('lerp', () {
    const a = BullTypography.standard;
    final b = a.copyWith(body: a.body.copyWith(fontSize: 20));

    test('interpolates every role', () {
      expect(a.lerp(b, 0.5).body.fontSize, 18);
      expect(a.lerp(b, 0.5).caption.fontSize, a.caption.fontSize);
    });

    test('returns the endpoints at 0 and 1', () {
      expect(a.lerp(b, 0).body.fontSize, 16);
      expect(a.lerp(b, 1).body.fontSize, 20);
    });

    test('returns itself when the other side is missing', () {
      expect(a.lerp(null, 0.5), same(a));
    });
  });

  group('context.bullType', () {
    testWidgets('reads the registered scale', (tester) async {
      late BullTypography type;
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) {
              type = context.bullType;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(type, same(BullTypography.standard));
    });

    testWidgets('throws a StateError when none is registered', (tester) async {
      Object? error;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [testBullTheme]),
          home: Builder(
            builder: (context) {
              try {
                context.bullType;
              } on StateError catch (e) {
                error = e;
              }
              return const SizedBox();
            },
          ),
        ),
      );
      expect(error, isA<StateError>());
      expect('$error', contains('BullTypography'));
    });
  });

  group('BullText', () {
    testWidgets('a role draws its style, recoloured and reweighted', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullText(
            'word',
            role: BullTextRole.caption,
            color: Color(0xFF123456),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      final style = tester.widget<Text>(find.text('word')).style;
      expect(style?.fontSize, BullTypography.standard.caption.fontSize);
      expect(style?.height, BullTypography.standard.caption.height);
      expect(style?.color, const Color(0xFF123456));
      expect(style?.fontWeight, FontWeight.w700);
    });

    testWidgets('a role follows the registered scale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              testBullTheme,
              BullShapes.standard,
              BullTypography.standard.copyWith(
                body: const TextStyle(fontSize: 30),
              ),
            ],
          ),
          home: const BullText('word', role: BullTextRole.body),
        ),
      );
      expect(tester.widget<Text>(find.text('word')).style?.fontSize, 30);
    });

    test('refuses a role and a style together', () {
      expect(
        () =>
            BullText('word', role: BullTextRole.body, style: const TextStyle()),
        throwsAssertionError,
      );
    });
  });
}
