import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class GetPayjoinTradingEnabledUsecase {
  final PayjoinPolicyAccess _policy;

  const GetPayjoinTradingEnabledUsecase(this._policy);

  Future<bool> execute() async => switch (await _policy.load()) {
    Ok(:final value) => value.tradingEnabled,
    Err() => false,
  };
}
