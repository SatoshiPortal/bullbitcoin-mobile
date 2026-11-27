import 'package:exchange/exchange.dart';
import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart';

/// The fee estimates of the session's bitcoin network.
class GetFeeOptionsUsecase {
  final Fees _fees;

  const GetFeeOptionsUsecase(this._fees);

  Future<Result<FeeOptions, ExchangeFeeEstimatesUnavailableFailure>> execute(
    ExchangeSession session,
  ) async {
    final bitcoin = session.environment == ExchangeEnvironment.testnet
        ? BitcoinNetwork.testnet
        : BitcoinNetwork.mainnet;
    return switch (await _fees.estimate(bitcoin)) {
      Ok(:final value) => Ok(value),
      Err(:final failure) => Err(
        ExchangeFeeEstimatesUnavailableFailure('${failure.runtimeType}'),
      ),
    };
  }
}
