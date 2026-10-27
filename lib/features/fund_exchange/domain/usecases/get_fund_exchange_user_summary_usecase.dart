import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class GetFundExchangeUserSummaryUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  const GetFundExchangeUserSummaryUsecase({
    required this._getExchangeUserSummaryUsecase,
  });

  @useResult
  Future<Result<UserSummary, FundExchangeFailure>> execute() async {
    try {
      return Ok(await _getExchangeUserSummaryUsecase.execute());
    } catch (e, st) {
      // The shared core use-case still throws, so this is its boundary. Only
      // the type is logged: GetExchangeUserSummaryException's message is the
      // stringified cause, which can be the exchange API's own text, and the
      // on-device log can be shared. warning, not severe: this is usually
      // transport, not a bug.
      log.warning(
        'Failed to load the exchange user summary: ${e.runtimeType}',
        trace: st,
      );
      return Err(
        FundExchangeUnexpectedFailure(
          'getExchangeUserSummary failed: ${e.runtimeType}',
        ),
      );
    }
  }
}
