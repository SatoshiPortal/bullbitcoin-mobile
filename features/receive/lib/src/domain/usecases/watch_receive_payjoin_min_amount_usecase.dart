import 'package:bull_payjoin/bull_payjoin.dart';

import 'watch_receive_payjoin_enabled_usecase.dart';

class WatchReceivePayjoinMinAmountUsecase {
  final PayjoinPolicyAccess _policy;

  const WatchReceivePayjoinMinAmountUsecase(this._policy);

  Stream<int> execute() =>
      watchReceivePayjoinPolicy(_policy)
          .map((policy) => policy.minimumAmount.value.toInt())
          .distinct();
}
