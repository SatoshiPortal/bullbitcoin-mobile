import 'package:bull_ark/src/domain/ark_display_data_port.dart';
import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';
import 'package:bull_ark/src/ui/ark_exit_request_screen.dart';
import 'package:bull_ark/src/ui/ark_payment_screen.dart';
import 'package:bull_ark/src/ui/ark_vtxos_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_account_screen_test.dart' as wallet;
import 'ark_exit_request_screen_test.dart' as request;
import 'ark_exits_screen_test.dart' as exits;
import 'ark_information_widget_test.dart' show app, config;
import 'ark_operations_test.dart' show account;
import 'ark_payment_cubit_test.dart' as payment;
import 'ark_vtxos_screen_test.dart' as vtxos;

void main() {
  final preferences = <BullAmountSnapshot?>[
    null,
    const BullAmountSnapshot(
      unit: BitcoinUnit.sats,
      hideAmounts: false,
      isReady: false,
    ),
    const BullAmountSnapshot(
      unit: BitcoinUnit.sats,
      hideAmounts: true,
      isReady: true,
    ),
  ];
  for (var index = 0; index < preferences.length; index++) {
    testWidgets(
      'passive Ark amounts remain private in preference state $index',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final controller = wallet.controller(
            wallet.Client()..snapshot = Ok(wallet.observation()),
          );
          final sender = payment.PaymentRig();
          final screens = <Widget>[
            wallet.screen(controller, []),
            ArkBoardAmountScreen(
              config: config(),
              onReviewRequest: (_, _) {},
              displayData: ArkDisplayData(
                account: account(),
                walletId: 'source',
                available: Sats.fromInt(1234),
              ),
            ),
            ArkPaymentScreen(
              cubit: sender.cubit,
              initialDestination: payment.destination,
              observedSpendable: Sats.fromInt(1234),
              onReconcile: () {},
            ),
            ArkVtxosScreen(
              snapshot: vtxos.view(),
              renewalThresholdBlocks: 1008,
              onRenew: (_) async => false,
            ),
            exits.Harness(exits.view()).screen,
            ArkExitRequestScreen(
              snapshot: request.inventory(),
              onReview: (_) {},
            ),
          ];
          for (final screen in screens) {
            await tester.pumpWidget(
              app(screen, amountPreferences: preferences[index]),
            );
            await tester.pumpAndSettle();
            for (final amount in [
              '1,234 sats',
              '1234 sats',
              '1234',
              '1,000 sats',
              '1000 sats',
              '1000',
              '42',
              '56',
            ]) {
              expect(
                find.text(amount),
                findsNothing,
                reason: screen.runtimeType.toString(),
              );
            }
            expect(
              find.text('••••'),
              findsWidgets,
              reason: screen.runtimeType.toString(),
            );
            expect(
              find.bySemanticsLabel(RegExp(r'1,234 sats|1234 sats')),
              findsNothing,
            );
          }
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'explicit quote facts remain readable for the confirmation decision',
    (tester) async {
      final rig = payment.PaymentRig();
      await rig.ready();
      await tester.pumpWidget(
        app(
          ArkPaymentScreen(cubit: rig.cubit, onReconcile: () {}),
          amountPreferences: const BullAmountSnapshot(
            unit: BitcoinUnit.sats,
            hideAmounts: true,
            isReady: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('900 sats'), findsWidgets);
      expect(find.text('100 sats'), findsOneWidget);
      expect(find.widgetWithText(BullButton, 'Confirm'), findsOneWidget);
      expect(rig.client.calls, ['quote']);
    },
  );
}
