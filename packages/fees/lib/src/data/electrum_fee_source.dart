import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import '../domain/fees_entity.dart';
import '../domain/fees_failure.dart';

class ElectrumFeeSource {
  final WalletConnectionPort _connections;

  const ElectrumFeeSource(this._connections);

  Future<Result<FeeOptions, FeesFailure>> estimate(
    BitcoinNetwork network,
  ) async {
    final targets = network == BitcoinNetwork.regtest
        ? const [1, 3, 6]
        : const [1, 6, 24];
    try {
      final result = await _connections.run<FeeOptions>(
        network: network,
        operation: (connection) async {
          final estimates = await estimateBitcoinFees(
            connection,
            targets: targets,
          );
          switch (estimates) {
            case Err(:final failure):
              return Err(failure);
            case Ok(:final value):
              try {
                return Ok(mapElectrumFeeEstimates(value));
              } on FormatException {
                return const Err(SyncConnectionFailure());
              }
          }
        },
        mayRetry: (failure) => failure is SyncConnectionFailure,
      );
      return result.mapErr((_) => const FeeEstimateUnavailableFailure());
    } on Exception {
      return const Err(FeeEstimateUnavailableFailure());
    }
  }
}
