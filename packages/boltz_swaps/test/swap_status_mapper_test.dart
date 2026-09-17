import 'package:bull_sdk/boltz.dart' as boltz;
import 'package:boltz_swaps/src/data/models/swap_model.dart';
import 'package:boltz_swaps/src/data/swap_status_mapper.dart';
import 'package:boltz_swaps/src/domain/entities/swap.dart';
import 'package:test/test.dart';

void main() {
  const mapper = SwapStatusMapper();
  final now = DateTime(2026, 9, 9);

  LnSendSwapModel submarine({String? sendTxid, String status = 'pending'}) =>
      SwapModel.lnSend(
            id: 'sub-1',
            type: SwapType.liquidToLightning.name,
            status: status,
            keyIndex: 0,
            creationTime: DateTime(2026, 9).millisecondsSinceEpoch,
            sendWalletId: 'w-liquid',
            invoice: 'lnbc1',
            paymentAddress: 'lq1lockup',
            paymentAmount: 100000,
            sendTxid: sendTxid,
          )
          as LnSendSwapModel;

  test('txnMempool records the Boltz-reported lockup txid when none is '
      'stored — the row must never read as "no funds moved"', () {
    final mapping = mapper.map(
      swap: submarine(),
      boltzStatus: boltz.SwapStatus.txnMempool,
      transactionId: 'boltz-saw-lockup',
      now: now,
    );

    final updated = (mapping as SwapUpdated).swap as LnSendSwapModel;
    expect(updated.status, SwapStatus.paid.name);
    expect(updated.sendTxid, 'boltz-saw-lockup');
  });

  test('the app-recorded broadcast txid stays authoritative', () {
    final mapping = mapper.map(
      swap: submarine(sendTxid: 'app-recorded'),
      boltzStatus: boltz.SwapStatus.txnConfirmed,
      transactionId: 'boltz-saw-different',
      now: now,
    );

    final updated = (mapping as SwapUpdated).swap as LnSendSwapModel;
    expect(updated.sendTxid, 'app-recorded');
  });

  test('a later failure event routes a lockup recorded only via events to '
      'refundable, not terminal', () {
    final withTxid = mapper.map(
      swap: submarine(),
      boltzStatus: boltz.SwapStatus.txnMempool,
      transactionId: 'boltz-saw-lockup',
      now: now,
    );
    final paid = (withTxid as SwapUpdated).swap as LnSendSwapModel;

    final failure = mapper.map(
      swap: paid,
      boltzStatus: boltz.SwapStatus.txnLockupFailed,
      now: now,
    );

    final outcome = (failure as SwapUpdated).swap as LnSendSwapModel;
    expect(outcome.status, SwapStatus.refundable.name);
  });
}
