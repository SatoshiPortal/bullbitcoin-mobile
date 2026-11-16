import 'package:bb_mobile/features/bullvault/domain/bitcoin_chain_tip_port.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

final class BitcoinChainTipAdapter implements BitcoinChainTipPort {
  final WalletConnectionPort _connections;

  const BitcoinChainTipAdapter(this._connections);

  @override
  Future<({int height, int medianTimePast})> getChainTip({
    required BitcoinNetwork network,
  }) async {
    final result = await _connections.run(
      network: network,
      operation: (connection) =>
          bitcoinPolicyChainState(connection, includeMedianTimePast: true),
      mayRetry: (failure) => failure is SyncConnectionFailure,
    );
    return switch (result) {
      Ok(
        value: (
          tipHeight: final height,
          medianTimePast: final int time,
          referenceMedianTimes: _,
        ),
      ) =>
        (height: height, medianTimePast: time),
      _ => throw const FormatException('Chain time is unavailable'),
    };
  }
}
