import 'package:bull_ui/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onboarding/src/ui/widgets/splash_mark.dart';

/// The splash mark paints its four shapes as four [Opacity] layers:
/// `tl, tr, bl, br`.
List<double> _opacities(WidgetTester tester) => tester
    .widgetList<Opacity>(
      find.descendant(
        of: find.byType(SplashMark),
        matching: find.byType(Opacity),
      ),
    )
    .map((Opacity opacity) => opacity.opacity)
    .toList();

Widget _app({
  bool disableAnimations = false,
  bool reduceMotion = false,
  double height = 127,
}) {
  return MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        reduceMotion: reduceMotion,
      ),
      child: Scaffold(
        body: Center(child: SplashMark(height: height)),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('keyframes', () {
    test('a shape stays transparent until its own 15.79 % keyframe', () {
      expect(SplashMark.fillAt(0, 0), 0);
      expect(SplashMark.fillAt(0, 0.1), 0);
      expect(SplashMark.fillAt(0, SplashMark.transparentUntil), 0);
    });

    test('a shape ramps between 15.79 % and 17.54 % then stays filled', () {
      final double middle =
          (SplashMark.transparentUntil + SplashMark.filledFrom) / 2;
      expect(SplashMark.fillAt(0, middle), closeTo(0.5, 0.001));
      expect(SplashMark.fillAt(0, SplashMark.filledFrom), 1);
      expect(SplashMark.fillAt(0, 0.9), 1);
    });

    test('each shape runs on its own delayed timeline', () {
      // 50 / 100 / 150 ms of the 950 ms cycle.
      expect(SplashMark.shapeDelays, <double>[0, 1 / 19, 2 / 19, 3 / 19]);
      // Before its own start a shape backs `animation-fill-mode: backwards`
      // and stays transparent rather than flashing its base fill.
      expect(SplashMark.fillAt(1, 0), 0);
      expect(SplashMark.fillAt(2, 0.05), 0);
      expect(SplashMark.fillAt(3, 0.15), 0);
      // ... while the first shape is already filled at the same instant.
      expect(SplashMark.fillAt(0, 0.1754), 1);
      // Each shape clears its own window, one delay after the previous one.
      expect(SplashMark.fillAt(1, 1 / 19), 0);
      expect(SplashMark.fillAt(1, 1 / 19 + SplashMark.filledFrom), 1);
    });

    test('the cycle wraps back to transparent', () {
      expect(SplashMark.fillAt(0, 1), 0);
      expect(SplashMark.fillAt(0, 1.05), 0);
    });
  });

  group('cascade', () {
    testWidgets('the hand-off frame shows the fully filled mark', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      expect(_opacities(tester), <double>[1, 1, 1, 1]);
    });

    testWidgets('the four shapes refill in order, 50 ms apart', (tester) async {
      await tester.pumpWidget(_app());

      // 665 ms into the cycle the whole mark is clear: each shape is inside
      // its own transparent window.
      await tester.pump(const Duration(milliseconds: 665));
      expect(_opacities(tester), <double>[0, 0, 0, 0]);

      // Then the shapes come back in `tl, tr, bl, br` order.
      await tester.pump(const Duration(milliseconds: 142));
      expect(_opacities(tester), <double>[1, 0, 0, 0]);

      await tester.pump(const Duration(milliseconds: 48));
      expect(_opacities(tester), <double>[1, 1, 0, 0]);

      await tester.pump(const Duration(milliseconds: 48));
      expect(_opacities(tester), <double>[1, 1, 1, 0]);

      await tester.pump(const Duration(milliseconds: 48));
      expect(_opacities(tester), <double>[1, 1, 1, 1]);
    });

    testWidgets('the cascade repeats every 950 ms', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump(SplashMark.cycleDuration);
      expect(_opacities(tester), <double>[1, 1, 1, 1]);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });
  });

  group('reduced motion', () {
    testWidgets(
      'disableAnimations shows the static mark and stops the ticker',
      (tester) async {
        await tester.pumpWidget(_app(disableAnimations: true));
        expect(_opacities(tester), <double>[1, 1, 1, 1]);
        expect(tester.binding.transientCallbackCount, 0);

        await tester.pump(const Duration(milliseconds: 400));
        expect(_opacities(tester), <double>[1, 1, 1, 1]);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets('reduceMotion shows the static mark and stops the ticker', (
      tester,
    ) async {
      await tester.pumpWidget(_app(reduceMotion: true));
      expect(_opacities(tester), <double>[1, 1, 1, 1]);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('turning the preference on and off while mounted', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(_app(disableAnimations: true));
      expect(_opacities(tester), <double>[1, 1, 1, 1]);
      // `MaterialApp` animates its own theme transition on this rebuild; the
      // mark's ticker has to be gone as soon as that settles.
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 0);
      expect(_opacities(tester), <double>[1, 1, 1, 1]);

      await tester.pumpWidget(_app());
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      expect(_opacities(tester), <double>[1, 1, 1, 1]);

      // Leave no ticker behind for the test binding.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('disposing the splash leaves no running ticker', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sizes the mark from the source viewBox ratio', (tester) async {
    await tester.pumpWidget(_app());
    final Size size = tester.getSize(find.byType(SplashMark));
    expect(size.height, 127);
    expect(size.width, closeTo(127 * 2975 / 2512, 0.01));

    await tester.pumpWidget(_app(height: 64));
    final Size small = tester.getSize(find.byType(SplashMark));
    expect(small.height, 64);
    expect(small.width, closeTo(64 * 2975 / 2512, 0.01));
  });

  testWidgets('the mark is decorative and stays out of the semantics tree', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(_app());

    // ExcludeSemantics wraps the whole lockup, and `flutter_svg` adds one per
    // picture: nothing inside the mark can reach the tree.
    expect(
      find.descendant(
        of: find.byType(SplashMark),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    final List<SvgPicture> pictures = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .toList();
    expect(pictures, hasLength(4));
    expect(pictures.every((SvgPicture p) => p.excludeFromSemantics), isTrue);
    expect(pictures.every((SvgPicture p) => p.semanticsLabel == null), isTrue);
    expect(find.bySemanticsLabel(RegExp(r'\S')), findsNothing);

    handle.dispose();
  });

  test('the four mark SVGs decode to the source canvas', () async {
    // `SvgPicture` silently falls back to a placeholder when a graphic fails to
    // parse, so the widget tests above would pass on a broken asset. Decoding
    // each file proves it is readable and still 2975 x 2512.
    for (final String shape in <String>['tl', 'tr', 'bl', 'br']) {
      final PictureInfo info = await vg.loadPicture(
        SvgAssetLoader(
          'assets/splash/bb-mark-$shape.svg',
          packageName: 'onboarding',
        ),
        null,
      );
      expect(info.size.width, 2975, reason: shape);
      expect(info.size.height, 2512, reason: shape);
      info.picture.dispose();
    }
  });

  test(
    'the four mark assets and the camo texture ship with the package',
    () async {
      for (final String name in <String>[
        'bb-mark-tl.svg',
        'bb-mark-tr.svg',
        'bb-mark-bl.svg',
        'bb-mark-br.svg',
        'splash_camo.png',
      ]) {
        final ByteData data = await rootBundle.load(
          'packages/onboarding/assets/splash/$name',
        );
        expect(data.lengthInBytes, greaterThan(0), reason: name);
      }
    },
  );
}
