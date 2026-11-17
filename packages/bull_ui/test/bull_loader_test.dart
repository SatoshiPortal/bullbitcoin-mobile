import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif/gif.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(
  Widget child, {
  BullLoaderTheme loader = BullLoaderTheme.standard,
  bool reducedMotion = false,
}) {
  return MaterialApp(
    theme: ThemeData(
      extensions: bullUiExtensions(
        colors: testBullTheme,
        brightness: Brightness.light,
        loader: loader,
      ),
    ),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('shows the cubes by default', (tester) async {
    await tester.pumpWidget(_app(const BullLoader.large()));
    expect(
      tester.getSize(find.byType(BullLoader)),
      const Size.square(BullLoader.largeSize),
    );
    expect(find.byType(Gif), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows a capped spinner when the theme picks it', (tester) async {
    await tester.pumpWidget(
      _app(
        const BullLoader.large(),
        loader: const BullLoaderTheme(style: BullLoaderStyle.spinner),
      ),
    );
    expect(
      tester.getSize(find.byType(BullLoader)),
      const Size.square(BullLoader.largeSize),
    );
    expect(find.byType(Gif), findsNothing);
    expect(
      tester.getSize(find.byType(CircularProgressIndicator)),
      const Size.square(BullLoader.maxIndicatorSize),
    );
  });

  for (final style in BullLoaderStyle.values) {
    testWidgets('shows a still clock with reduced motion ($style)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const BullLoader.small(),
          loader: BullLoaderTheme(style: style),
          reducedMotion: true,
        ),
      );
      expect(find.byIcon(BullIcons.schedule), findsOneWidget);
      expect(find.byType(Gif), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }

  testWidgets('is hidden from semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const BullLoader.small()));
    expect(
      find.descendant(
        of: find.byType(BullLoader),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('names the missing theme when none is registered', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [testBullTheme]),
        home: const BullLoader.small(),
      ),
    );
    expect(
      tester.takeException(),
      isA<StateError>().having(
        (e) => e.message,
        'message',
        contains('BullLoaderTheme'),
      ),
    );
  });
}
