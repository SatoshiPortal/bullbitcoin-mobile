import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

void main() {
  testWidgets('shows the selected language, without a globe, and reports the '
      'pick', (tester) async {
    String? picked;
    await tester.pumpWidget(
      wrapWithTheme(
        BullLanguagePicker<String>(
          value: 'en',
          onChanged: (value) => picked = value,
          languages: const [
            BullPickerItem(value: 'en', label: 'English'),
            BullPickerItem(value: 'fr', label: 'Français'),
          ],
        ),
      ),
    );

    expect(find.text('English'), findsOneWidget);
    expect(find.byIcon(Icons.language), findsNothing);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();

    expect(picked, 'fr');
  });
}
