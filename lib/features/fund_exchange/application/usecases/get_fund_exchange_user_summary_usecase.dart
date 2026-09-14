import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
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
    } catch (e) {
      return Err(
        FundExchangeUnexpectedFailure(
          'getExchangeUserSummary failed: ${e.runtimeType}',
        ),
      );
    }
  }
}
