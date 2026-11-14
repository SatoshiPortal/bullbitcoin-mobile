import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/features/send/data/broadcast_failure_mapper.dart';
import 'package:bb_mobile/features/send/domain/broadcast_failure.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:primitives/primitives.dart' show Err, LiquidNetwork, Ok;
import 'package:sync/sync.dart'
    show WalletConnectionPort, broadcastLiquidTransaction;

/// Broadcasts through sync, on the servers [WalletConnectionPort] selects.
class LiquidBlockchainRepositoryImpl implements LiquidBlockchainRepository {
  final WalletConnectionPort _connections;

  const LiquidBlockchainRepositoryImpl({required this._connections});

  /// Throws [CategorizedBroadcastException] when the broadcast fails.
  @override
  Future<String> broadcastTransaction({
    required String signedPset,
    required Network network,
  }) async {
    final result = await broadcastLiquidTransaction(
      signedPset,
      network: switch (network) {
        Network.liquidMainnet => LiquidNetwork.mainnet,
        Network.liquidTestnet => LiquidNetwork.testnet,
        Network.liquidRegtest => LiquidNetwork.regtest,
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
