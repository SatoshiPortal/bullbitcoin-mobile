import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullSettingsEntryItem', () {
    testWidgets('draws the leading widget instead of the icon', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullSettingsEntryItem(
            icon: Icons.code,
            title: 'Source code',
            leading: SizedBox(key: ValueKey('glyph')),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('glyph')), findsOneWidget);
      expect(find.byIcon(Icons.code), findsNothing);
    });

    testWidgets('keeps the icon without a leading widget', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullSettingsEntryItem(icon: Icons.code, title: 'Source code'),
        ),
      );

      expect(find.byIcon(Icons.code), findsOneWidget);
    });
  });
}
