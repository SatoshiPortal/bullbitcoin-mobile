import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

/// Whether payjoin is enabled for Bull Bitcoin exchange trades (buy/sell/
/// pay orders) — the trading setting, independent of the disclaimer-gated
/// global payjoin setting. Shared by the pay and sell flows.
class GetPayjoinTradingEnabledUsecase {
  final PayjoinPolicyAccess _policy;

  const GetPayjoinTradingEnabledUsecase(this._policy);

  Future<bool> execute() async => switch (await _policy.load()) {
    Ok(:final value) => value.tradingEnabled,
    Err() => false,
  };
}
