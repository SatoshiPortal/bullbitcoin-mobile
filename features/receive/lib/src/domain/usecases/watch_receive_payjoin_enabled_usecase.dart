import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

class WatchReceivePayjoinEnabledUsecase {
  final PayjoinPolicyAccess _policy;

  const WatchReceivePayjoinEnabledUsecase(this._policy);

  Stream<bool> execute() =>
      watchReceivePayjoinPolicy(_policy)
          .map((p) => p.receiveEnabled)
          .distinct();
}

/// Match the shared Settings view on a failed policy read: no inbound Payjoin,
/// and the normal minimum while there is no readable saved policy.
Stream<PayjoinPolicy> watchReceivePayjoinPolicy(
  PayjoinPolicyAccess policy,
) async* {
  try {
    await for (final result in policy.watch()) {
      switch (result) {
        case Ok(:final value):
          yield value;
        case Err(:final failure):
          log.warning(
            'Receive Payjoin policy unavailable: ${failure.runtimeType}',
          );
          yield PayjoinPolicy.defaults();
      }
    }
  } on Exception catch (error, trace) {
    log.warning(
      'Receive Payjoin policy watch failed: ${error.runtimeType}',
      trace: trace,
    );
    yield PayjoinPolicy.defaults();
  }
}
