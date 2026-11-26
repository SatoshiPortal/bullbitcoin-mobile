import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

void main() {
  testWidgets('keeps the row, amount and status actions independent', (
    tester,
  ) async {
    final actions = <String>[];
    await tester.pumpWidget(
      wrapWithTheme(
        BullTransactionListItem(
          BullTransactionListItemData(
            icon: Icons.arrow_downward,
            iconBackgroundColor: testBullTheme.surface,
            iconBorderColor: testBullTheme.border,
            amount: TextButton(
              onPressed: () => actions.add('amount'),
              child: const Text('10,000 sats'),
            ),
            labels: const [],
            networkLabel: 'Bitcoin',
            networkColor: testBullTheme.surface,
            status: TextButton(
              onPressed: () => actions.add('status'),
              child: const Text('Verifying'),
            ),
            onTap: () => actions.add('details'),
          ),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    try {
      expect(find.bySemanticsLabel('10,000 sats'), findsOneWidget);
      expect(find.bySemanticsLabel('Verifying'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
    expect(
      tester.getSize(find.byType(BullTransactionListItem)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('10,000 sats'));
    await tester.tap(find.text('Verifying'));
    await tester.tap(find.text('Bitcoin'));
    expect(actions, ['amount', 'status', 'details']);
  });
}
