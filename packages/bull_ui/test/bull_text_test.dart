import 'package:auto_size_text/auto_size_text.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

void main() {
  testWidgets('only line-bounded text uses the auto-sizing layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const Column(
          children: [
            ListTile(title: BullText('Plain constrained title')),
            SizedBox(
              width: 130,
              child: BullText(
                'A longer constrained value',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    final autosized = tester.widget<AutoSizeText>(find.byType(AutoSizeText));
    expect(autosized.data, 'A longer constrained value');
    expect(autosized.maxLines, 1);
    expect(autosized.overflow, TextOverflow.ellipsis);
    expect(find.text('Plain constrained title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
