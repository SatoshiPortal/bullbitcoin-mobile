import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/entities/account_info.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Wraps the shared exchange use-case, which still throws, so the cubit above
/// can switch on a `Result` instead of catching.
class GetAccountInfoUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  const GetAccountInfoUsecase({required this._getExchangeUserSummaryUsecase});

  @useResult
  Future<Result<AccountInfo, ExchangeSettingsFailure>> execute() async {
    try {
      final summary = await _getExchangeUserSummaryUsecase.execute();
      return Ok(
        AccountInfo(
          userNumber: summary.userNumber,
          email: summary.email,
          firstName: summary.profile.firstName,
          lastName: summary.profile.lastName,
          verificationLevel: _verificationLevel(summary),
        ),
      );
    } catch (e, st) {
      log.severe(message: 'getExchangeUserSummary failed', error: e, trace: st);
      return Err(
        ExchangeSettingsAccountUnavailableFailure(
          'getExchangeUserSummary failed: ${e.runtimeType}',
        ),
      );
    }
  }

  VerificationLevel _verificationLevel(UserSummary summary) {
    if (summary.isFullyVerifiedKycLevel) {
      return VerificationLevel.identityVerified;
    } else if (summary.isLightKycLevel) {
      return VerificationLevel.light;
    } else if (summary.isLimitedKycLevel) {
      return VerificationLevel.limited;
    } else {
      return VerificationLevel.notVerified;
    }
  }
}
