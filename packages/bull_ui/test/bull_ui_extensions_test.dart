import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

T _registered<T>(List<ThemeExtension<dynamic>> extensions) =>
    extensions.whereType<T>().single;

void main() {
  test("registers Bull's shapes and typography by default", () {
    final extensions = bullUiExtensions(
      colors: testBullTheme,
      brightness: Brightness.light,
    );
    expect(_registered<BullShapes>(extensions), same(BullShapes.standard));
    expect(
      _registered<BullTypography>(extensions),
      same(BullTypography.standard),
    );
  });

  testWidgets('widgets read the shapes and typography the app passes', (
    tester,
  ) async {
    final shapes = BullShapes.standard.copyWith(card: 9);
    final typography = BullTypography.standard.withFamily('DM Sans');
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: bullUiExtensions(
            colors: testBullTheme,
            brightness: Brightness.light,
            shapes: shapes,
            typography: typography,
          ),
        ),
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(context.bullShapes, same(shapes));
    expect(context.bullType, same(typography));
  });
}
