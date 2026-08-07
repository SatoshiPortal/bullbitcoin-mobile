import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class WatchPayjoinPolicyUsecase {
  final PayjoinPolicyAccess _policy;

  const WatchPayjoinPolicyUsecase(this._policy);

  Stream<PayjoinPolicy> execute() async* {
    try {
      await for (final result in _policy.watch()) {
        switch (result) {
          case Ok(:final value):
            yield value;
          case Err():
            yield PayjoinPolicy.defaults();
        }
      }
    } catch (_) {
      yield PayjoinPolicy.defaults();
    }
  }
}
