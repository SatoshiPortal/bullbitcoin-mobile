import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// The jurisdiction whose recipient types should be offered first: the one
/// of the market of the user's exchange account currency, from the catalog.
/// Null when the account has no currency the app has a market for; then no
/// jurisdiction is offered first.
///
class GetPreferredJurisdictionUsecase {
  final Exchange _exchange;

  const GetPreferredJurisdictionUsecase(this._exchange);

  @useResult
  Future<Result<Jurisdiction?, RecipientsFailure>> execute() async {
    switch (await _exchange.getUserSummary()) {
      case Ok(value: final summary):
        final currency = summary.currency;
        if (currency == null) return const Ok(null);
        return Ok(switch (ExchangeCatalog.parse(currency)) {
          KnownCurrency(:final market) => market.jurisdiction,
          UnknownCurrency() => null,
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
