import 'package:mempool/mempool.dart';
import 'package:primitives/primitives.dart';

typedef ReadMempoolEnvironment =
    Future<Result<BitcoinNetwork, MempoolFailure>> Function();

Future<Result<T, MempoolFailure>> withMempoolSettingsNetwork<T>(
  ReadMempoolEnvironment readEnvironment, {
  required bool isLiquid,
  required Future<Result<T, MempoolFailure>> Function(Network) operation,
}) async {
  switch (await readEnvironment()) {
    case Err(:final failure):
      return Err(failure);
    case Ok(value: final bitcoin):
      final Network? network = isLiquid
          ? LiquidNetwork.tryFromName(bitcoin.name)
          : bitcoin;
      if (network == null) {
        return Err(MempoolUnsupportedNetworkFailure(bitcoin));
      }
      return operation(network);
  }
}
