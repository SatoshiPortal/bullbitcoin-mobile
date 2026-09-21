import 'package:bull_logger/bull_logger.dart';
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
          case Err(:final failure):
            // Degrade to defaults rather than breaking the settings screen,
            // but never silently: this is how a mis-stored policy hides.
            log.warning(
              'Payjoin policy unreadable, using defaults: '
              '${failure.runtimeType}',
            );
            yield PayjoinPolicy.defaults();
        }
      }
    } catch (e, st) {
      log.severe(
        message: 'Payjoin policy watch failed',
        error: e.runtimeType,
        trace: st,
      );
      yield PayjoinPolicy.defaults();
    }
  }
}
