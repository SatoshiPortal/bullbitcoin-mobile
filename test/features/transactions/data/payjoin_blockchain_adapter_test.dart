import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:bb_mobile/features/transactions/data/payjoin_blockchain_adapter.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' hide Network;

final class _Servers implements ElectrumServersPort {
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

  Future<void> broadcast({
    required Future<Result<BitcoinBroadcastReceipt, WalletSpendFailure>>
    Function(String, BitcoinNetwork, Future<String> Function())
    gate,
    String Function(String psbt)? transactionId,
  }) =>
      AppPayjoinBlockchainAdapter(
        const BdkBitcoinBlockchainDatasource(),
        servers,
        WalletFacade(const Stream.empty(), broadcastBitcoin: gate),
        transactionId: transactionId ?? (_) => 'txid',
      ).broadcastPsbt(
        walletId: 'wallet-1',
        network: BitcoinNetwork.testnet,
        psbt: 'psbt',
      );

  test('an unreadable payload is reported as never attempted', () async {
    var gated = false;
    await expectLater(
      broadcast(
        gate: (_, _, _) async {
          gated = true;
          throw StateError('unreachable');
        },
        transactionId: (_) => throw const FormatException('bad psbt'),
      ),
      throwsA(isA<PayjoinBroadcastNotAttemptedException>()),
    );
    expect(gated, isFalse);
    expect(servers.calls, 0);
  });

  test('a wallet failure before the network callback is reported as never '
      'attempted', () async {
    await expectLater(
      broadcast(
        gate: (_, _, _) async => throw const WalletSpendBlockedException(
          BitcoinSpendStatus.unavailable,
        ),
      ),
      throwsA(isA<PayjoinBroadcastNotAttemptedException>()),
    );
    expect(servers.calls, 0);
  });

  test('a spend refusal stays a spend refusal', () async {
    await expectLater(
      broadcast(
        gate: (_, _, _) async => const Err(
          WalletSpendBlockedFailure(BitcoinSpendStatus.unavailable),
        ),
      ),
      throwsA(isA<PayjoinSpendBlockedException>()),
    );
    expect(servers.calls, 0);
  });

  test('a failure inside the network callback keeps its unknown '
      'outcome', () async {
    await expectLater(
      broadcast(
        gate: (_, _, send) async {
          await send();
          throw StateError('unreachable');
        },
      ),
      throwsStateError,
    );
    expect(servers.calls, 1);
  });
}
