import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class GetSellConfidentialSepaAvailabilityUsecase {
  final Exchange _exchange;

  const GetSellConfidentialSepaAvailabilityUsecase(this._exchange);

  @useResult
  Future<Result<ConfidentialSepaAvailability, SellFailure>> execute(
    FiatCurrency currency,
  ) async {
    if (currency != FiatCurrency.eur) {
      return const Ok(ConfidentialSepaAvailability.unavailable);
    }
    return switch (await _exchange.getConfidentialSepaAvailability()) {
      Ok(:final value) => Ok(value),
      Err(failure: ExchangeNetworkFailure()) => const Err(SellNetworkFailure()),
      Err() => const Err(SellUnexpectedFailure()),
    };
  }
}
