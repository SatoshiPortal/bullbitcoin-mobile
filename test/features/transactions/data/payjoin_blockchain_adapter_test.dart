import '../../../scripted_wallet_connections.dart';

import 'package:transactions/testing.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:sync/sync.dart'
    show
        BitcoinSpendStatus,
        SignedPsbt,
        SpendOwner,
        SpendReceipt,
        SyncFailure,
        SyncBusyFailure,
        SyncConnectionFailure,
        SyncInvalidTransactionFailure,
        SyncOutcomeUnknownFailure,
        SyncProtectedInputsFailure,
        SyncSpendBlockedFailure;

void main() {
  late ScriptedWalletConnections servers;

  setUp(() => servers = ScriptedWalletConnections());

  Future<void> broadcast(Result<SpendReceipt, SyncFailure> outcome) =>
      AppPayjoinBlockchainAdapter(servers, (
        walletId,
        transaction, {
        required network,
        built,
        owner,
        replacing,
      }) async {
        expect(walletId, 'wallet-1');
        expect((transaction as SignedPsbt).psbt, 'psbt');
        expect(network, BitcoinNetwork.testnet);
        // The session alone may spend the inputs it reserved.
        expect(owner, SpendOwner(protocol: 'payjoin', session: 'session-1'));
        return outcome;
      }).broadcastPsbt(
        walletId: 'wallet-1',
        sessionId: 'session-1',
        network: BitcoinNetwork.testnet,
        psbt: 'psbt',
      );

  test('an accepted spend completes, durable or not', () async {
    await broadcast(
      const Ok(SpendReceipt('txid', durable: false, guarded: true)),
    );
    expect(servers.networks, isEmpty);
  });

  for (final failure in <SyncFailure>[
    const SyncInvalidTransactionFailure(),
    SyncProtectedInputsFailure(),
    const SyncConnectionFailure(),
  ]) {
    test('${failure.logCode} is reported as never attempted', () async {
      await expectLater(
        broadcast(Err(failure)),
        throwsA(isA<PayjoinBroadcastNotAttemptedException>()),
      );
    });
  }

  for (final (failure, busy) in <(SyncFailure, bool)>[
    (const SyncSpendBlockedFailure(BitcoinSpendStatus.pending), false),
    (const SyncBusyFailure(), true),
  ]) {
    test('a ${failure.logCode} refusal stays a spend refusal', () async {
      await expectLater(
        broadcast(Err(failure)),
        throwsA(
          isA<PayjoinSpendBlockedException>().having(
            (refusal) => refusal.busy,
            'busy',
            busy,
          ),
        ),
      );
    });
  }

  test('an unknown outcome is never reported as not attempted', () async {
    await expectLater(
      broadcast(const Err(SyncOutcomeUnknownFailure())),
      throwsStateError,
    );
  });
}
