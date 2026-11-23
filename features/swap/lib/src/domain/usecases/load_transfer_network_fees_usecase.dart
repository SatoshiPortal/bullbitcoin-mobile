import 'package:swaps/order_swaps.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:fees/fees.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

typedef TransferNetworkFees = ({FeeOptions bitcoin, FeeOptions liquid});

class LoadTransferNetworkFeesUsecase {
  final Fees _fees;

  const LoadTransferNetworkFeesUsecase({required this._fees});

  @useResult
  Future<Result<TransferNetworkFees, SwapFailure>> execute(
    NetworkEnv environment,
  ) async {
    final liquid = LiquidNetwork.tryFromName(environment.name);
    if (liquid == null) {
      return const Err(SwapUnexpectedFailure('UnsupportedNetworkException'));
    }
    final bitcoin = BitcoinNetwork.fromName(environment.name);
    final (liquidResult, bitcoinResult) = await (
      _fees.estimate(liquid),
      _fees.estimate(bitcoin),
    ).wait;
    switch ((liquidResult, bitcoinResult)) {
      case (Ok(value: final liquidOptions), Ok(value: final bitcoinOptions)):
        return Ok((bitcoin: bitcoinOptions, liquid: liquidOptions));
      case (Err(:final failure), _) || (_, Err(:final failure)):
        final reason =
            'Network fee estimation unavailable: ${failure.runtimeType}';
        log.warning(reason);
        return Err(SwapUnexpectedFailure(reason));
    }
  }
}
