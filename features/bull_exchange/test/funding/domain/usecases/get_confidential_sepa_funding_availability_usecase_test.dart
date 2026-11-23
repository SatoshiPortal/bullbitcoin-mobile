import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/funding/domain/fund_exchange_failure.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_confidential_sepa_funding_availability_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Result<bool, FundExchangeFailure>> run(
    Result<bool, ExchangeFailure> availability,
  ) => GetConfidentialSepaFundingAvailabilityUsecase(
    exchangeForTesting(
      isConfidentialSepaFundingAvailable: () async => availability,
    ),
  ).execute();

  bool offered(Result<bool, FundExchangeFailure> result) =>
      (result as Ok<bool, FundExchangeFailure>).value;

  test(
    'is offered to an eligible user before the virtual IBAN exists',
    () async {
      expect(offered(await run(const Ok(true))), isTrue);
    },
  );

  test('is not offered to a user who cannot use it', () async {
    expect(offered(await run(const Ok(false))), isFalse);
  });

  test('a network failure keeps its meaning', () async {
    final result = await run(const Err(ExchangeNetworkFailure()));

    expect(
      (result as Err<bool, FundExchangeFailure>).failure,
      isA<FundExchangeNetworkFailure>(),
    );
  });

  test('account unavailability is unexpected for funding', () async {
    final result = await run(const Err(ExchangeAccountUnavailableFailure()));

    expect(
      (result as Err<bool, FundExchangeFailure>).failure,
      isA<FundExchangeUnexpectedFailure>(),
    );
  });
}
