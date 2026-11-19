import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('shows the badge and a named delete button', (tester) async {
    var deleted = 0;
    await tester.pumpWidget(
      wrapWithTheme(
        BullServerTile(
          title: 'host:50002',
          statusColor: Colors.green,
          statusLabel: 'Online',
          badgeLabel: 'Encrypted',
          onDelete: () => deleted++,
          deleteTooltip: 'Delete server',
        ),
      ),
    );

    expect(find.bySemanticsLabel('host:50002'), findsOneWidget);
    expect(find.text('Encrypted'), findsOneWidget);
    expect(find.byTooltip('Delete server'), findsOneWidget);
    expect(
      tester.getSize(find.byTooltip('Delete server')).shortestSide,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.byTooltip('Delete server'));
    expect(deleted, 1);
  });

  testWidgets('hides delete and shows the unused label when disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const BullServerTile(
          title: 'host:50002',
          statusColor: Colors.green,
          statusLabel: 'Online',
          badgeLabel: 'Unencrypted',
          badgeIsWarning: true,
          disabled: true,
          disabledLabel: 'Not used',
        ),
      ),
    );

    expect(find.text('Not used'), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
  });
}
