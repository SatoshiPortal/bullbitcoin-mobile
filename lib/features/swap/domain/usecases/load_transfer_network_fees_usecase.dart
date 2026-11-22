import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    as wallet
    show Network, NetworkX;
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
    final liquid = wallet.Network.fromEnvironment(
      environment: environment,
      isLiquid: true,
    );
    final bitcoin = wallet.Network.fromEnvironment(
      environment: environment,
      isLiquid: false,
    );
    final (liquidResult, bitcoinResult) = await (
      _fees.estimate(liquid.shared),
      _fees.estimate(bitcoin.shared),
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
