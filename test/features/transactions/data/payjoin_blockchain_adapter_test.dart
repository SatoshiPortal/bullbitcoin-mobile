import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:electrum/electrum.dart';
import 'package:bb_mobile/features/transactions/data/payjoin_blockchain_adapter.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:sync/sync.dart'
    show
        SyncBusyFailure,
        SyncConnectionFailure,
        SyncInvalidTransactionFailure,
        SyncOutcomeUnknownFailure,
        SyncProtectedInputsFailure,
        SyncSpendBlockedFailure;

final class _Servers implements ElectrumServersPort {
  @override
  Future<bool> hasCustomServers({
    required ElectrumServerNetwork network,
  }) async => false;

  int calls = 0;

  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  }) {
    calls++;
    throw StateError('connection reset after send');
  }
}

void main() {
  late _Servers servers;

  setUp(() => servers = _Servers());

  Future<void> broadcast(Result<SpendReceipt, SyncFailure> outcome) =>
      AppPayjoinBlockchainAdapter(
        const BdkBitcoinBlockchainDatasource(),
        servers,
        WalletFacade(
          const Stream.empty(),
          broadcastSpend:
              (
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
                expect(
                  owner,
                  SpendOwner(protocol: 'payjoin', session: 'session-1'),
                );
                return outcome;
              },
        ),
      ).broadcastPsbt(
        walletId: 'wallet-1',
        sessionId: 'session-1',
        network: BitcoinNetwork.testnet,
        psbt: 'psbt',
      );

  test('an accepted spend completes, durable or not', () async {
    await broadcast(
      const Ok(SpendReceipt('txid', durable: false, guarded: true)),
    );
    expect(servers.calls, 0);
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
