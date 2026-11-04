import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// The jurisdiction whose recipient types should be offered first, derived
/// from the currency on the user's exchange account.
///
/// This is the feature's boundary for the shared exchange use-case, which
/// still throws. It also owns the currency-to-jurisdiction mapping, which was
/// previously a `switch` in the bloc — a business decision, not presentation.
class GetPreferredJurisdictionUsecase {
  /// Used when the account currency is unknown, and by callers when this
  /// use-case fails. Declared here so both paths agree on one value.
  static const defaultJurisdiction = 'CA';

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  const GetPreferredJurisdictionUsecase(this._getExchangeUserSummaryUsecase);

  @useResult
  Future<Result<String, RecipientsFailure>> execute() async {
    try {
      final summary = await _getExchangeUserSummaryUsecase.execute();
      return Ok(switch (summary.currency) {
        'EUR' => 'EU',
        'MXN' => 'MX',
        'CRC' => 'CR',
        'ARS' => 'AR',
        'COP' => 'CO',
        _ => defaultJurisdiction,
      });
    } on Object catch (e, st) {
      log.warning(
        'Could not read the exchange summary for a preferred jurisdiction',
        error: e,
        trace: st,
      );
      return const Err(RecipientsUnexpectedFailure());
    }
  }
}
