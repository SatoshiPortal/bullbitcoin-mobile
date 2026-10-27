import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/entities/account_owner_name.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// The legal name on the user's exchange account, which a virtual IBAN is
/// issued in.
class GetAccountOwnerNameUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  const GetAccountOwnerNameUsecase(this._getExchangeUserSummaryUsecase);

  @useResult
  Future<Result<AccountOwnerName, RecipientsFailure>> execute() async {
    try {
      final profile = (await _getExchangeUserSummaryUsecase.execute()).profile;
      return Ok(
        AccountOwnerName(
          firstName: profile.firstName.trim(),
          lastName: profile.lastName.trim(),
        ),
      );
    } on Object catch (e, st) {
      log.warning(
        'Could not read the exchange summary for the account owner name',
        error: e,
        trace: st,
      );
      return const Err(RecipientsUnexpectedFailure());
    }
  }
}
