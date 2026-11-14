import 'package:bb_mobile/features/send/data/broadcast_failure_mapper.dart';
import 'package:bb_mobile/features/send/domain/broadcast_failure.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Err, Ok;
import 'package:sync/sync.dart'
    show WalletConnectionPort, broadcastBitcoinTransaction, decodeBitcoinPsbt;

/// Broadcasts through sync, on the servers [WalletConnectionPort] selects: the
/// privacy and fallback rule lives in that port alone.
class BitcoinBlockchainRepository {
  final WalletConnectionPort _connections;

  const BitcoinBlockchainRepository({required this._connections});

  /// Throws [CategorizedBroadcastException] when the broadcast fails.
  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required Network network,
  }) async => switch (decodeBitcoinPsbt(finalizedPsbt)) {
    Ok(:final value) => await broadcastTransaction(
      value.bytes,
      network: network,
    ),
    Err(:final failure) => throw CategorizedBroadcastException(
      broadcastFailureCategory(failure),
    ),
  };

  /// Throws [CategorizedBroadcastException] when the broadcast fails.
  Future<String> broadcastTransaction(
    List<int> transaction, {
    required Network network,
  }) async {
    final result = await broadcastBitcoinTransaction(
      transaction,
      network: switch (network) {
        Network.bitcoinMainnet => BitcoinNetwork.mainnet,
        Network.bitcoinTestnet => BitcoinNetwork.testnet,
        Network.bitcoinRegtest => BitcoinNetwork.regtest,
        _ => throw const UnsupportedNetworkException(),
      },
      connections: _connections,
    );
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw CategorizedBroadcastException(
        broadcastFailureCategory(failure),
      ),
    };
  }
}
