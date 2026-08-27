import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('removable chip invokes onRemove from its close target', (
    tester,
  ) async {
    var removed = false;
    await tester.pumpWidget(
      wrapWithTheme(
        BullFilterChip(label: 'Date', onRemove: () => removed = true),
      ),
    );

    await tester.tap(find.byIcon(BullIcons.close));
    expect(removed, isTrue);
  });

  testWidgets('selectable chip invokes whole-chip selection semantics', (
    tester,
  ) async {
    bool? selected;
    await tester.pumpWidget(
      wrapWithTheme(
        BullFilterChip.selectable(
          label: 'Info',
          selected: false,
          onSelected: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.text('Info'));
    expect(selected, isTrue);
    expect(find.byIcon(BullIcons.close), findsNothing);
  });
}
