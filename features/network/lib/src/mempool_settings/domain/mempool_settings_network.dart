import 'package:mempool/mempool.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

Future<Result<T, MempoolFailure>> withMempoolSettingsNetwork<T>(
  Result<Environment, PreferencesFailure> environment, {
  required bool isLiquid,
  required Future<Result<T, MempoolFailure>> Function(Network) operation,
}) async {
  switch (environment) {
    case Err(:final failure):
      return Err(MempoolUnexpectedFailure(failure.logMessage));
    case Ok(:final value):
      final bitcoin = BitcoinNetwork.fromName(value.name);
      if (!NetworkCapabilities.supports(
        bitcoin,
        NetworkCapability.publicExplorer,
      )) {
        return Err(MempoolUnsupportedNetworkFailure(bitcoin));
      }
      final Network? network = isLiquid
          ? LiquidNetwork.tryFromName(bitcoin.name)
          : bitcoin;
      if (network == null) {
        return Err(MempoolUnsupportedNetworkFailure(bitcoin));
      }
      return operation(network);
  }
}
