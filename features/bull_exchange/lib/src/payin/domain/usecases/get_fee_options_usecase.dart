import 'package:exchange/exchange.dart';
import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart';

/// The fee estimates of the session's bitcoin network; null when they can't
/// be read.
class GetFeeOptionsUsecase {
  final Fees _fees;

  const GetFeeOptionsUsecase(this._fees);

  Future<FeeOptions?> execute(ExchangeSession session) async {
    final bitcoin = session.environment == ExchangeEnvironment.testnet
        ? BitcoinNetwork.testnet
        : BitcoinNetwork.mainnet;
    return switch (await _fees.estimate(bitcoin)) {
      Ok(:final value) => value,
      Err() => null,
    };
  }
}
