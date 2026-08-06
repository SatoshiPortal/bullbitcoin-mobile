import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class GetBuyPayjoinEnabledUsecase {
  final PayjoinPolicyAccess _policy;

  const GetBuyPayjoinEnabledUsecase(this._policy);

  Future<bool> execute() async => switch (await _policy.load()) {
    Ok(:final value) => value.enabled,
    Err() => false,
  };
}
