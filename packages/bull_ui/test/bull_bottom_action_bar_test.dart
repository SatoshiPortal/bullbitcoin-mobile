import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

Widget _action(String label) =>
    BullButton.primary(label: label, onPressed: () {});

void main() {
  testWidgets('stacks two actions on a narrow layout', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        SizedBox(
          width: 320,
          child: BullBottomActionBar(
            actions: [_action('Continue'), _action('Back')],
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(BullBottomActionBar),
        matching: find.byType(Row),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('keeps two actions horizontal when there is room', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        SizedBox(
          width: 600,
          child: BullBottomActionBar(
            actions: [_action('Continue'), _action('Back')],
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(BullBottomActionBar),
        matching: find.byType(Row),
      ),
      findsNWidgets(3),
    );
  });
}
