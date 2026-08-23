import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

/// Regular sends follow the payjoin SEND setting (on by default,
/// disclaimer-free), independent of the receive and trading settings.
class GetSendPayjoinEnabledUsecase {
  final PayjoinPolicyAccess _policy;

  const GetSendPayjoinEnabledUsecase(this._policy);

  Future<bool> execute() async => switch (await _policy.load()) {
    Ok(:final value) => value.sendEnabled,
    Err() => false,
  };
}
