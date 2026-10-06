import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Wraps the shared exchange use-case, which still throws, so the cubit above
/// can switch on a `Result` instead of catching.
class GetExchangeSettingsAccountUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  const GetExchangeSettingsAccountUsecase({
    required this._getExchangeUserSummaryUsecase,
  });

  @useResult
  Future<Result<UserSummary, ExchangeSettingsFailure>> execute() async {
    try {
      return Ok(await _getExchangeUserSummaryUsecase.execute());
    } catch (e, st) {
      log.severe(message: 'getExchangeUserSummary failed', error: e, trace: st);
      return Err(
        ExchangeSettingsAccountUnavailableFailure(
          'getExchangeUserSummary failed: ${e.runtimeType}',
        ),
      );
    }
  }
}
