import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class GetBuyPayjoinEnabledUsecase {
  final PayjoinPolicyAccess _policy;

  const GetBuyPayjoinEnabledUsecase(this._policy);

  @useResult
  Future<Result<bool, BuyFailure>> execute() async {
    switch (await _policy.load()) {
      case Ok(:final value):
        return Ok(value.enabled);
      case Err(:final failure):
        log.warning(
          'Could not read the Payjoin policy',
          error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
        );
        return Err(BuyUnexpectedFailure(failure.logMessage));
    }
  }
}
