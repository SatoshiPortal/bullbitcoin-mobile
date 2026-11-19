import 'package:bull_ui/bull_ui.dart' show BullBorderedTile, BullButton;
import 'package:flutter_test/flutter_test.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_exits_screen_test.dart' show Harness, view, exitRow;

void main() {
  testWidgets('observed exit opens a dedicated detail instead of nested rows', (
    tester,
  ) async {
    final rig = Harness(
      view(
        rows: [
          exitRow(),
          exitRow(id: 'other'),
        ],
      ),
    );
    await tester.pumpWidget(app(rig.screen));
    await tester.tap(find.byType(BullBorderedTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(BullBorderedTile), findsNothing);
    expect(
      find.widgetWithText(BullButton, 'Start emergency exit'),
      findsNothing,
    );
    expect(find.text('shared'), findsOneWidget);
    expect(rig.untouched, isTrue);
  });
  testWidgets('observed exit detail offers a local Done', (tester) async {
    final rig = Harness(view());
    await tester.pumpWidget(app(rig.screen));
    await tester.tap(find.byType(BullBorderedTile).first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(BullButton, 'Done'), findsOneWidget);
  });
  testWidgets('stale exit remains readable but cannot review a claim', (
    tester,
  ) async {
    final rig = Harness(view(stale: true));
    await tester.pumpWidget(app(rig.screen));
    await tester.tap(find.byType(BullBorderedTile).first);
    await tester.pumpAndSettle();
    final claim = tester.widget<BullButton>(
      find.widgetWithText(BullButton, 'Claim'),
    );
    expect(claim.disabled, isTrue);
    claim.onPressed();
    expect(rig.untouched, isTrue);
    expect(find.text('shared'), findsOneWidget);
  });
}
