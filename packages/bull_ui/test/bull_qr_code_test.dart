import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

final paints = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is QrPainter,
);
final longData = 'lnbc1${List.filled(600, 'a').join()}';
Widget app(
  Widget child, {
  Size box = const Size(157.9, 100.25),
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness, extensions: testBullExtensions),
  home: Center(
    child: SizedBox.fromSize(size: box, child: child),
  ),
);
QrPainter painter(WidgetTester tester) =>
    switch (tester.widget<CustomPaint>(paints).painter) {
      final QrPainter painter => painter,
      _ => throw StateError('Missing QR painter'),
    };

void main() {
  for (final data in ['public', longData]) {
    testWidgets(
      'fractional tight nonsquare constraints retain painted module margin length=${data.length}',
      (tester) async {
        await tester.pumpWidget(app(BullQrCode(data: data, size: 200)));
        final qr = find.byType(QrImageView);
        final outer = tester.getSize(qr);
        final content = tester.getSize(paints);
        final modules = 17 + 4 * painter(tester).version;
        final step = content.width / modules;
        final offset = tester.getTopLeft(paints) - tester.getTopLeft(qr);
        expect(outer.width, outer.height);
        expect(outer.width, lessThanOrEqualTo(100.25));
        expect(content.width, content.height);
        expect(step * 2, (step * 2).floorToDouble());
        expect(offset.dx, closeTo(4 * step, 0.000001));
        expect(offset.dy, closeTo(4 * step, 0.000001));
        expect(
          outer.width - content.width - offset.dx,
          closeTo(4 * step, 0.000001),
        );
        expect(
          outer.height - content.height - offset.dy,
          closeTo(4 * step, 0.000001),
        );
        expect(tester.widget<QrImageView>(qr).gapless, true);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final brightness in Brightness.values) {
    testWidgets('fixed opaque theme roles in $brightness', (tester) async {
      await tester.pumpWidget(
        app(
          const BullQrCode(data: 'public', size: 100),
          brightness: brightness,
        ),
      );
      final image = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(image.backgroundColor, testBullTheme.surfaceFixed);
      expect(image.backgroundColor.a, 1);
      expect(painter(tester).eyeStyle.color, testBullTheme.onSurfaceFixed);
      expect(
        painter(tester).dataModuleStyle.color,
        testBullTheme.onSurfaceFixed,
      );
    });
  }
  testWidgets(
    'new content updates the painted symbol and empty content removes it',
    (tester) async {
      await tester.pumpWidget(app(const BullQrCode(data: 'short', size: 100)));
      final before = painter(tester);
      await tester.pumpWidget(app(BullQrCode(data: longData, size: 100)));
      expect(painter(tester).version, greaterThan(before.version));
      expect(painter(tester).shouldRepaint(before), true);
      await tester.pumpWidget(app(const BullQrCode(data: '', size: 100)));
      expect(paints, findsNothing);
    },
  );
  for (final box in [Size.zero, const Size(1, 2)]) {
    testWidgets('zero/tiny constraints use bounded fallback $box', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(const BullQrCode(data: 'public', size: 100), box: box),
      );
      expect(paints, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'successful label is localized once; omitted label is decorative',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          app(
            const BullQrCode(
              data: 'public-payload',
              size: 100,
              semanticsLabel: 'Adresse Ark',
            ),
          ),
        );
        expect(find.bySemanticsLabel('Adresse Ark'), findsOneWidget);
        expect(find.bySemanticsLabel('qr code'), findsNothing);
        expect(find.bySemanticsLabel('public-payload'), findsNothing);
        await tester.pumpWidget(
          app(const BullQrCode(data: 'public-payload', size: 100)),
        );
        expect(find.bySemanticsLabel('Adresse Ark'), findsNothing);
        expect(find.bySemanticsLabel('qr code'), findsNothing);
        expect(find.bySemanticsLabel('public-payload'), findsNothing);
        expect(paints, findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );
  for (final data in ['', List.filled(10000, 'x').join()]) {
    testWidgets(
      'invalid content keeps error semantics without a success image length=${data.length}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            app(
              BullQrCode(
                data: data,
                size: 100,
                semanticsLabel: 'Adresse Ark',
                errorBuilder: (_) => Semantics(
                  label: 'QR indisponible',
                  child: const SizedBox(),
                ),
              ),
            ),
          );
          expect(find.bySemanticsLabel('QR indisponible'), findsOneWidget);
          expect(find.bySemanticsLabel('Adresse Ark'), findsNothing);
          expect(find.bySemanticsLabel('qr code'), findsNothing);
          expect(paints, findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  test('programmer sizes must be finite and positive', () {
    for (final size in [0.0, -1.0, double.infinity, double.nan]) {
      expect(
        () => BullQrCode(data: 'public', size: size),
        throwsAssertionError,
      );
    }
  });
}
