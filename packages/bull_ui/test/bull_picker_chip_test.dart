import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

void main() {
  group('BullPickerChip', () {
    testWidgets('shows the selected label and reports the pick', (
      tester,
    ) async {
      String? picked;
      await tester.pumpWidget(
        wrapWithTheme(
          BullPickerChip<String>(
            value: 'a',
            onChanged: (value) => picked = value,
            items: const [
              BullPickerItem(value: 'a', label: 'Apple'),
              BullPickerItem(value: 'b', label: 'Banana'),
            ],
          ),
        ),
      );

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsNothing);

      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banana'));
      await tester.pumpAndSettle();

      expect(picked, 'b');
    });

    testWidgets('reads in primary with a chevron', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          BullPickerChip<String>(
            value: 'a',
            onChanged: (_) {},
            items: const [BullPickerItem(value: 'a', label: 'Apple')],
          ),
        ),
      );
      final label = tester.widget<Text>(find.text('Apple'));
      expect(label.style?.color, testBullTheme.primary);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });
  });

  testWidgets('BullPickerMenu opens from any child', (tester) async {
    String? picked;
    await tester.pumpWidget(
      wrapWithTheme(
        BullPickerMenu<String>(
          value: 'a',
          onChanged: (value) => picked = value,
          items: const [
            BullPickerItem(value: 'a', label: 'Apple'),
            BullPickerItem(value: 'b', label: 'Banana'),
          ],
          child: const Text('12.34 USD'),
        ),
      ),
    );

    await tester.tap(find.text('12.34 USD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banana'));
    await tester.pumpAndSettle();

    expect(picked, 'b');
  });
}
