import 'package:ark/ark.dart';
import 'package:bull_ark/src/presentation/ark_payment_cubit.dart';
import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';
import 'package:bull_ark/src/ui/ark_information_screen.dart';
import 'package:bull_ark/src/ui/ark_payment_screen.dart';
import 'package:bull_ark/src/ui/ark_receive_screen.dart';
import 'package:bull_ark/src/ui/ark_settings_screen.dart';
import 'package:bull_ark/src/ui/ark_vtxos_screen.dart';
import 'package:bull_ui/bull_ui.dart' show Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_flow_visual_fixtures.dart';
import 'ark_account_screen_test.dart' as wallet;
import 'ark_board_screen_test.dart' as board;
import 'ark_exits_screen_test.dart' as exits;
import 'ark_information_widget_test.dart' as information;
import 'ark_payment_cubit_test.dart' as payment;
import 'ark_receive_flow_test.dart' as receive;
import 'ark_settings_flow_test.dart' as settings;
import 'ark_vtxos_screen_test.dart' as vtxos;
import 'fake_ark_client.dart';

typedef ArkVisualCapture = Future<void> Function(
  String name,
  Widget screen, {
  Future<void> Function(WidgetTester)? arrange,
});

Widget arkFeeReserveVisualFixture() {
  final source = information.config();
  return ArkInformationScreen(
    config: source,
    snapshot: ArkSnapshot(
      account: source.id,
      revision: 2,
      observedAt: DateTime.utc(2026, 11, 18),
      stale: false,
      confirmedReserve: Sats.zero,
      reserveAddress: 'bcrt1qpublicfeereservefixtureforhostrenderonly',
    ),
  );
}

/// Package-owned screen fixtures expose widgets, never internal controllers.
Future<void> captureArkVisualFixtures(ArkVisualCapture capture) async {
  await capture(
    'ArkInfoFeeReserve',
    ArkInformationScreen(
      snapshot: ArkSnapshot(
        account: information.config().id,
        revision: 2,
        observedAt: DateTime.utc(2026, 11, 18),
        confirmedReserve: Sats.zero,
        reserveAddress: 'bcrt1qpublicfeereservefixtureforhostrenderonly',
      ),
      config: information.config(),
    ),
  );
  final client = wallet.Client()..snapshot = Ok(wallet.observation());
  final cubit = wallet.controller(client);
  await capture('SendArkWallet', wallet.screen(cubit, []));
  final unknown = wallet.controller(
    wallet.Client()..snapshot = Ok(wallet.observation(missing: true)),
  );
  await capture('SendArkWalletUnavailable', wallet.screen(unknown, []));
  final receiver = receive.controller(
    FakeArkClient()
      ..destination = Ok(
        ArkReceiveDestination(
          kind: ArkDestinationKind.ark,
          value: 'ark1publicfixtureaddressforlayoutonly',
        ),
      ),
  );
  addTearDown(receiver.close);
  await capture('SendArkReceiveEditing', ArkReceiveScreen(cubit: receiver));
  await receiver.request(lightning: false, amount: '');
  await capture(
    'SendArkReceive',
    ArkReceiveScreen(cubit: receiver, onShare: (_) {}),
  );
  final sender = payment.PaymentRig();
  await capture(
    'SendArkScan',
    ArkPaymentScreen(
      cubit: sender.cubit,
      onReconcile: () {},
      onScan: () async => null,
    ),
  );
  final amountSender = payment.PaymentRig();
  await capture(
    'SendArkAmount',
    ArkPaymentScreen(
      cubit: amountSender.cubit,
      initialDestination: payment.destination,
      observedSpendable: Sats.fromInt(1234),
      onReconcile: () {},
    ),
  );
  await sender.ready();
  await capture(
    'SendArkConfirm',
    ArkPaymentScreen(cubit: sender.cubit, onReconcile: () {}),
  );
  sender.cubit.emit(
    ArkPaymentSubmitted(
      ArkOperation(
        id: 'public-payment-operation',
        kind: ArkOperationKind.payment,
        status: ArkOperationStatus.succeeded,
        chainSource: Uri.parse('http://localhost:3000'),
        configGeneration: 1,
      ),
    ),
  );
  await capture(
    'SendArkSent',
    ArkPaymentScreen(cubit: sender.cubit, onReconcile: () {}),
  );
  final boarding = board.Rig();
  await boarding.cubit.prepare(Sats.fromInt(1000));
  await capture('BoardConfirm', boarding.screen);
  await capture(
    'BoardAmount',
    ArkBoardAmountScreen(
      config: information.config(),
      onReviewRequest: (_, _) {},
    ),
  );
  await capture(
    'ArkInfo',
    ArkInformationScreen(snapshot: vtxos.view(), config: information.config()),
  );
  final preferences = settings.Fixture()..preferences.enabled = true;
  addTearDown(preferences.cubit.close);
  await capture(
    'ArkSettings',
    ArkSettingsScreen(cubit: preferences.cubit, onOpenAccount: (_) {}),
  );
  await capture(
    'Vtxos',
    ArkVtxosScreen(snapshot: vtxos.view(), onRenew: (_) {}),
  );
  await capture(
    'VtxosEmpty',
    ArkVtxosScreen(
      snapshot: vtxos.view(values: []),
      onRenew: (_) {},
    ),
  );
  await capture('EmergencyExit', exits.Harness(exits.view()).screen);
  await capture(
    'ExitEmpty',
    exits.Harness(exits.view(rows: [], exits: ArkExitStatus.none)).screen,
  );
  for (final frame in await arkFlowFrames()) {
    await capture(frame.name, frame.screen, arrange: frame.arrange);
  }
}
