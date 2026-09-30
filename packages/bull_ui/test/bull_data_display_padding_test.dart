import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('BullOptionsTag pads its text 8 across and 6 down', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithTheme(const BullOptionsTag(text: 'Tag')));

    final container = tester.widget<Container>(
      find.ancestor(of: find.text('Tag'), matching: find.byType(Container)),
    );
    expect(
      container.padding,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  });

  testWidgets('BullBorderedTile defaults to 15 across and 12 down', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(const BullBorderedTile(child: Text('Row'))),
    );

    final padding = tester.widget<Padding>(
      find.ancestor(of: find.text('Row'), matching: find.byType(Padding)).first,
    );
    expect(
      padding.padding,
      const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    );
  });
}
