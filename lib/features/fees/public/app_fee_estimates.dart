import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network, NetworkX;
import 'package:bull_logger/bull_logger.dart';
import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Err, Ok;

/// Resolves the app's current network for legacy flows without a wallet input.
class AppFeeEstimates {
  final Fees _fees;
  final Preferences _settingsRepository;

  AppFeeEstimates({required this._fees, required this._settingsRepository});

  Future<FeeOptions> execute({required bool isLiquid, Network? network}) async {
    try {
      final requestedNetwork =
          network ??
          Network.fromEnvironment(
            environment: (await _settingsRepository.fetch()).fold(
              (value) => value.environment.networkEnv,
              (failure) => throw const AppFeeEstimateException(),
            ),
            isLiquid: isLiquid,
          );
      if (requestedNetwork.isLiquid != isLiquid) {
        throw const AppFeeEstimateException();
      }
      return switch (await _fees.estimate(requestedNetwork.shared)) {
        Ok(:final value) => value,
        Err() => throw const AppFeeEstimateException(),
      };
    } on Exception catch (error) {
      log.warning('Network fee estimation unavailable: ${error.runtimeType}');
      throw const AppFeeEstimateException();
    }
  }
}

final class AppFeeEstimateException implements Exception {
  const AppFeeEstimateException();
}

/// Maps the Mempool probe into the network status reader's exception contract.
Future<void> probeMempoolFees(Fees fees, BitcoinNetwork network) async {
  if (await fees.estimate(network, source: FeeSource.mempool) case Err()) {
    throw const AppFeeEstimateException();
  }
}
