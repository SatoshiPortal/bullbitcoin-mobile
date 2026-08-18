import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('provides top bar, safe area and a scrollable body', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const BullPage(
          topBar: BullTopBar(title: 'Coins'),
          scrollable: true,
          child: SizedBox(height: 900, child: Text('Content')),
        ),
      ),
    );

    expect(find.byType(BullScaffold), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Coins'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
  });

  testWidgets('does not add safe area when the caller owns it', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(const BullPage(safeArea: false, child: Text('Root page'))),
    );

    expect(find.byType(SafeArea), findsNothing);
    expect(find.text('Root page'), findsOneWidget);
  });

  testWidgets('accepts caller-owned dynamic chrome', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const BullPage(
          topBar: SizedBox(height: 48, child: Text('Selection actions')),
          child: Text('Selected coins'),
        ),
      ),
    );

    expect(find.text('Selection actions'), findsOneWidget);
    expect(find.text('Selected coins'), findsOneWidget);
  });
}
