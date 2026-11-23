import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// The jurisdiction whose recipient types should be offered first, derived
/// from the currency on the user's exchange account.
///
class GetPreferredJurisdictionUsecase {
  /// Used when the account currency is unknown, and by callers when this
  /// use-case fails. Declared here so both paths agree on one value.
  static const defaultJurisdiction = 'CA';

  final Exchange _exchange;

  const GetPreferredJurisdictionUsecase(this._exchange);

  @useResult
  Future<Result<String, RecipientsFailure>> execute() async {
    switch (await _exchange.getUserSummary()) {
      case Ok(value: final summary):
        return Ok(switch (summary.currency) {
          'EUR' => 'EU',
          'MXN' => 'MX',
          'CRC' => 'CR',
          'ARS' => 'AR',
          'COP' => 'CO',
          _ => defaultJurisdiction,
        });
      case Err(:final failure):
        log.warning(
          'Could not read the exchange summary for a preferred jurisdiction',
          error: failure.runtimeType,
        );
        return const Err(RecipientsUnexpectedFailure());
    }
  }
}
