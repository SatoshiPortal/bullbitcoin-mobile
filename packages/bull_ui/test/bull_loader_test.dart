import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif/gif.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    theme: ThemeData(
      extensions: bullUiExtensions(
        colors: testBullTheme,
        brightness: Brightness.light,
      ),
    ),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('shows the cubes, never a spinner', (tester) async {
    await tester.pumpWidget(_app(const BullLoader.large()));
    expect(
      tester.getSize(find.byType(BullLoader)),
      const Size.square(BullLoader.largeSize),
    );
    expect(find.byType(Gif), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows a still clock with reduced motion', (tester) async {
    await tester.pumpWidget(
      _app(const BullLoader.small(), reducedMotion: true),
    );
    expect(find.byIcon(BullIcons.schedule), findsOneWidget);
    expect(find.byType(Gif), findsNothing);
  });

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
}
