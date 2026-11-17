import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('a long pasted value stays on one line', (tester) async {
    final pasted = 'lnbc1${'q' * 400}';
    await tester.pumpWidget(
      wrapWithTheme(BullPasteInput(text: pasted, onChanged: (_) {})),
    );

    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(find.text(pasted)).maxLines, 1);
  });
}
