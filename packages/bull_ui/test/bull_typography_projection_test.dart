import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final script in ScriptCategory.values) {
      testWidgets('resolved projection: $brightness / $script', (tester) async {
        final type = BullTypography.standard.resolved(
          brightness == Brightness.dark ? Colors.white : Colors.black,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: brightness,
              textTheme: type.toTextTheme(),
              extensions: [type],
            ),
            home: Builder(
              builder: (context) {
                final base = Theme.of(context);
                return Theme(
                  data: ThemeData.localize(
                    base,
                    base.typography.geometryThemeFor(script),
                  ),
                  child: Builder(
                    builder: (context) {
                      final slots = Theme.of(context).textTheme;
                      final roles = context.bullType;
                      final pairs = <(TextStyle?, TextStyle)>[
                        (slots.displayLarge, roles.display),
                        (slots.displayMedium, roles.display),
                        (slots.displaySmall, roles.headline),
                        (
                          slots.headlineLarge,
                          roles.subtitle.copyWith(fontWeight: FontWeight.w700),
                        ),
                        (
                          slots.headlineMedium,
                          roles.subtitle.copyWith(fontWeight: FontWeight.w500),
                        ),
                        (
                          slots.headlineSmall,
                          roles.subtitle.copyWith(fontWeight: FontWeight.w400),
                        ),
                        (slots.titleLarge, roles.title),
                        (
                          slots.titleMedium,
                          roles.body.copyWith(fontWeight: FontWeight.w500),
                        ),
                        (slots.titleSmall, roles.label),
                        (
                          slots.bodyLarge,
                          roles.body.copyWith(fontWeight: FontWeight.w500),
                        ),
                        (slots.bodyMedium, roles.body),
                        (
                          slots.bodySmall,
                          roles.label.copyWith(fontWeight: FontWeight.w400),
                        ),
                        (slots.labelLarge, roles.label),
                        (slots.labelMedium, roles.caption),
                        (slots.labelSmall, roles.caption),
                      ];
                      for (final (slot, role) in pairs) {
                        expect(slot, role);
                      }
                      return const SizedBox();
                    },
                  ),
                );
              },
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('resolution preserves explicit custom properties and is idempotent', () {
    final custom = BullTypography.standard.copyWith(
      body: BullTypography.standard.body.copyWith(
        color: Colors.red,
        letterSpacing: 2,
        textBaseline: TextBaseline.ideographic,
        leadingDistribution: TextLeadingDistribution.proportional,
      ),
    );
    final resolved = custom.resolved(Colors.white);
    expect(resolved.body, custom.body.copyWith(inherit: false));
    for (final role in BullTextRole.values) {
      expect(resolved.resolved(Colors.black).of(role), resolved.of(role));
    }
  });

  testWidgets('test composition projects the same resolved roles', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) {
            expect(Theme.of(context).textTheme, context.bullType.toTextTheme());
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
