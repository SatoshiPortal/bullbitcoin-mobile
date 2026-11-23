import 'package:exchange/exchange.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_failure.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_status.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class GetAutoBuyStatusUsecase {
  final Exchange _exchange;

  const GetAutoBuyStatusUsecase(this._exchange);

  @useResult
  Future<Result<AutoBuyStatus, AutoBuyFailure>> execute() async {
    return switch (await _exchange.getUserSummary()) {
      Ok(value: final summary) => Ok(
        AutoBuyStatus(
          isActive: summary.autoBuy.isActive,
          isRestricted: summary.isFundingRestricted,
        ),
      ),
      Err(:final failure) => Err(autoBuySummaryFailure(failure)),
    };
  }
}

AutoBuyFailure autoBuySummaryFailure(ExchangeFailure failure) {
  switch (failure) {
    case ExchangeUnsupportedNetworkFailure():
      return const AutoBuyUnsupportedNetworkFailure();
    case ExchangeNotAuthenticatedFailure() ||
        ExchangeCredentialReadFailure() ||
        ExchangeSessionRejectedFailure() ||
        ExchangeApiKeyStorageFailure():
      return const AutoBuyAccountUnavailableFailure();
    default:
      log.severe(
        message: 'Failed to load the AutoBuy account status',
        error: failure.runtimeType,
        trace: StackTrace.current,
      );
      return AutoBuyAccountUnavailableFailure(failure.runtimeType.toString());
  }
}
