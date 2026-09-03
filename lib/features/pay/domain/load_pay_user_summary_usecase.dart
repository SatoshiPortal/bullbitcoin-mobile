import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Pay's boundary onto the shared exchange summary read, which still throws.
class LoadPayUserSummaryUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  const LoadPayUserSummaryUsecase({
    required this._getExchangeUserSummaryUsecase,
  });

  @useResult
  Future<Result<UserSummary, PayFailure>> execute() async {
    try {
      return Ok(await _getExchangeUserSummaryUsecase.execute());
    } catch (e, st) {
      log.severe(
        message: 'Failed to load the exchange user summary',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }
}
