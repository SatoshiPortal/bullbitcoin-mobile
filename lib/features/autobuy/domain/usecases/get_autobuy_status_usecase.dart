import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/autobuy/domain/autobuy_failure.dart';
import 'package:bb_mobile/features/autobuy/domain/autobuy_status.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class GetAutoBuyStatusUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  const GetAutoBuyStatusUsecase(this._getExchangeUserSummaryUsecase);

  @useResult
  Future<Result<AutoBuyStatus, AutoBuyFailure>> execute() async {
    final UserSummary summary;
    try {
      summary = await _getExchangeUserSummaryUsecase.execute();
    } on Error {
      rethrow;
    } on GetExchangeUserSummaryException catch (e, st) {
      log.severe(
        message: 'Failed to load the AutoBuy account status',
        error: e,
        trace: st,
      );
      return Err(AutoBuyAccountUnavailableFailure('$e'));
    } catch (e, st) {
      log.severe(
        message: 'Failed to load the AutoBuy account status',
        error: e,
        trace: st,
      );
      return Err(AutoBuyUnexpectedFailure('$e'));
    }

    return Ok(
      AutoBuyStatus(
        isActive: summary.autoBuy.isActive,
        isRestricted: summary.isFundingRestricted,
      ),
    );
  }
}
