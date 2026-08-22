import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

/// Buy orders are exchange trades, so they follow the payjoin TRADING
/// setting (on by default, independent of the disclaimer-gated global
/// payjoin setting).
class GetBuyPayjoinEnabledUsecase {
  final PayjoinPolicyAccess _policy;

  const GetBuyPayjoinEnabledUsecase(this._policy);

  Future<bool> execute() async => switch (await _policy.load()) {
    Ok(:final value) => value.tradingEnabled,
    Err() => false,
  };
}
