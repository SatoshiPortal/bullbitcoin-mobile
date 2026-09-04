import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class LoadWithdrawContextUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  const LoadWithdrawContextUsecase({
    required this._getExchangeUserSummaryUsecase,
  });

  /// The exchange account summary, which the withdraw flow needs before it can
  /// show an amount screen.
  ///
  /// This is the boundary for the still-throwing core use-case: it is the first
  /// layer the withdraw feature owns.
  @useResult
  Future<Result<UserSummary, WithdrawFailure>> userSummary() async {
    try {
      return Ok(await _getExchangeUserSummaryUsecase.execute());
    } catch (e, st) {
      log.severe(
        message: 'Failed to load the exchange user summary',
        error: e,
        trace: st,
      );
      return Err(WithdrawUnexpectedFailure('$e'));
    }
  }
}
