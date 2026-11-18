import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final mode in AppThemeType.values) {
    testWidgets('app $mode projects its registered typography exactly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(mode),
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
    });
  }
}
