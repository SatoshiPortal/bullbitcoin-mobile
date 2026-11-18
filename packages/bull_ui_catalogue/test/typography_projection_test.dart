import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui_catalogue/catalogue_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'catalogue $brightness projects its registered typography exactly',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: catalogueThemeData(brightness),
            home: Builder(
              builder: (context) {
                expect(
                  Theme.of(context).textTheme,
                  context.bullType.toTextTheme(),
                );
                expect(context.bullType.body.color, context.bull.text);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
