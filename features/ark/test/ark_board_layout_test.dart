import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_display_data_port.dart';
import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullInputText;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Size;
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app, config;
import 'ark_operations_test.dart' show account;

void main() {
  for (final available in [0, 1000]) {
    testWidgets(
      'a known source balance $available cannot hand off a larger amount',
      (tester) async {
        final requested = <Sats>[];
        await tester.pumpWidget(
          app(
            ArkBoardAmountScreen(
              config: config(),
              displayData: ArkDisplayData(
                account: account(),
                walletId: 'source',
                available: Sats.fromInt(available),
              ),
              onReviewRequest: (_, amount) => requested.add(amount),
            ),
          ),
        );
        await tester.pumpAndSettle();
        tester
            .widget<BullInputText>(find.byType(BullInputText))
            .onChanged('${available + 1}');
        await tester.pump();
        final action = tester.widget<BullButton>(
          find.widgetWithText(BullButton, 'Continue'),
        );
        expect(action.disabled, isTrue);
        action.onPressed();
        expect(requested, isEmpty);
      },
    );
  }

  testWidgets('source observation stays informative and cannot enable Max', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requested = <Sats>[];
    await tester.pumpWidget(
      app(
        ArkBoardAmountScreen(
          config: config(),
          displayData: ArkDisplayData(
            account: account(),
            walletId: 'source',
            available: Sats.fromInt(184250),
          ),
          onReviewRequest: (_, amount) => requested.add(amount),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('184,250 sats'), findsOneWidget);
    final maximum = tester.widget<BullButton>(
      find.widgetWithText(BullButton, 'Max'),
    );
    expect(maximum.disabled, true);
    maximum.onPressed();
    expect(requested, isEmpty);
    final action = find.widgetWithText(BullButton, 'Continue');
    expect(tester.getBottomRight(action).dy, greaterThan(780));
    expect(tester.widget<BullButton>(action).disabled, true);
    tester.widget<BullInputText>(find.byType(BullInputText)).onChanged('60000');
    await tester.pump();
    expect(tester.widget<BullButton>(action).disabled, false);
    await tester.tap(action);
    expect(requested, [Sats.fromInt(60000)]);
  });

  testWidgets('a foreign source observation never becomes available funds', (
    tester,
  ) async {
    final owner = account();
    await tester.pumpWidget(
      app(
        ArkBoardAmountScreen(
          config: config(),
          displayData: ArkDisplayData(
            account: ArkAccountId(
              parent: owner.parent,
              network: owner.network,
              serverIdentity: 'other',
            ),
            walletId: 'source',
            available: Sats.fromInt(184250),
          ),
          onReviewRequest: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('184,250 sats'), findsNothing);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('0 sats'), findsNothing);
  });
}
