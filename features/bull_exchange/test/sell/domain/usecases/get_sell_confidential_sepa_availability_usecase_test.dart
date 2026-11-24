import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:bull_exchange/src/sell/domain/usecases/get_sell_confidential_sepa_availability_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('publishes every successful eligibility state', () async {
    for (final availability in ConfidentialSepaAvailability.values) {
      final exchange = exchangeForTesting(
        getConfidentialSepaAvailability: () async => Ok(availability),
      );
      final result = await GetSellConfidentialSepaAvailabilityUsecase(exchange)
          .execute(FiatCurrency.eur);
      expect(
        (result as Ok<ConfidentialSepaAvailability, SellFailure>).value,
        availability,
      );
    }
  });

  test('maps foreign failures to Sell failures', () async {
    for (final failure in [
      const ExchangeNetworkFailure(),
      const ExchangeUnexpectedFailure(),
    ]) {
      final exchange = exchangeForTesting(
        getConfidentialSepaAvailability: () async => Err(failure),
      );
      final result = await GetSellConfidentialSepaAvailabilityUsecase(exchange)
          .execute(FiatCurrency.eur);
      expect(
        (result as Err<ConfidentialSepaAvailability, SellFailure>).failure,
        failure is ExchangeNetworkFailure
            ? isA<SellNetworkFailure>()
            : isA<SellUnexpectedFailure>(),
      );
    }
  });

  test('other currencies are unavailable without a lookup', () async {
    final result = await GetSellConfidentialSepaAvailabilityUsecase(
      exchangeForTesting(),
    ).execute(FiatCurrency.cad);
    expect(
      (result as Ok<ConfidentialSepaAvailability, SellFailure>).value,
      ConfidentialSepaAvailability.unavailable,
    );
  });
}
