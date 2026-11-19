import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart' show BullBorderedTile;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_exits_screen_test.dart' show Harness, view, buttons;
import 'ark_information_widget_test.dart' show app;

void main() {
  testWidgets(
    'an old exit claim action cannot adopt a replacement publication',
    (tester) async {
      final first = Harness(view());
      await tester.pumpWidget(app(first.screen));
      final old = buttons(tester).first.onPressed;
      final next = Harness(view());
      await tester.pumpWidget(app(next.screen));
      old();
      expect(first.claims, isEmpty);
      expect(next.claims, isEmpty);
      buttons(tester).first.onPressed();
      expect(next.claims, [
        ['shared'],
      ]);
    },
  );

  testWidgets('exit detail shows native delay and real remaining blocks', (
    tester,
  ) async {
    final h = Harness(
      view(
        tip: 600,
        exits: ArkExitStatus.pending,
        rows: [
          ArkExit(
            id: 'observed-exit',
            amount: Sats.fromInt(60000),
            status: ArkExitStatus.pending,
            phase: ArkExitPhase.delay,
            confirmedHeight: 560,
            claimableHeight: 704,
          ),
        ],
      ),
    );
    await tester.pumpWidget(app(h.screen));
    await tester.tap(find.byType(BullBorderedTile).first);
    await tester.pump();
    expect(find.text('Unrolling exit transactions'), findsOneWidget);
    expect(find.text('Exit delay'), findsOneWidget);
    expect(find.text('104 blocks remaining'), findsOneWidget);
    expect(find.text('Confirmed at block 560'), findsOneWidget);
    expect(find.textContaining('automatically to'), findsNothing);
    expect(h.untouched, isTrue);
  });
}
