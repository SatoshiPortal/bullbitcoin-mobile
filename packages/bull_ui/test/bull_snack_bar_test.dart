import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('BullSnackBar fires the undo action callback', (tester) async {
    var undone = 0;
    late BuildContext ctx;

    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    BullSnackBar.show(
      ctx,
      message: '2 coins unfrozen',
      leadingIcon: BullIcons.acUnit,
      actionLabel: 'Undo',
      onAction: () => undone++,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('2 coins unfrozen'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(undone, 1);
  });
}
