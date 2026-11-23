import 'package:bull_exchange/src/recipients/domain/usecases/get_confidential_sepa_availability_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('returns each owned Exchange availability value unchanged', () async {
    for (final availability in ConfidentialSepaAvailability.values) {
      final exchange = exchangeForTesting(
        getConfidentialSepaAvailability: () async => Ok(availability),
      );
      final result = await GetConfidentialSepaAvailabilityUsecase(exchange)
          .execute();
      expect(
        (result as Ok<ConfidentialSepaAvailability, RecipientsFailure>).value,
        availability,
      );
    }
  });

  test('preserves network failure as a distinct recipients error', () async {
    final exchange = exchangeForTesting(
      getConfidentialSepaAvailability: () async =>
          const Err(ExchangeNetworkFailure()),
    );
    final result = await GetConfidentialSepaAvailabilityUsecase(exchange)
        .execute();
    expect(
      (result as Err<ConfidentialSepaAvailability, RecipientsFailure>).failure,
      isA<RecipientsNetworkFailure>(),
    );
  });
}
