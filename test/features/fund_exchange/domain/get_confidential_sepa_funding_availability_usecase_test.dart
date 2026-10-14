import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/get_confidential_sepa_funding_availability_usecase.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecipientsFacade extends Mock implements RecipientsFacade {}

void main() {
  late _MockRecipientsFacade facade;

  setUp(() => facade = _MockRecipientsFacade());

  Future<Result<bool, FundExchangeFailure>> run(
    Result<ConfidentialSepaAvailability, RecipientsFailure> availability,
  ) {
    when(
      () => facade.getConfidentialSepaAvailability(),
    ).thenAnswer((_) async => availability);
    return GetConfidentialSepaFundingAvailabilityUsecase(facade).execute();
  }

  bool offered(Result<bool, FundExchangeFailure> result) =>
      (result as Ok<bool, FundExchangeFailure>).value;

  test(
    'is offered to an eligible user before the virtual IBAN exists',
    () async {
      expect(
        offered(
          await run(const Ok(ConfidentialSepaAvailability.needsVirtualIban)),
        ),
        isTrue,
      );
    },
  );

  test('is offered to a user with an active virtual IBAN', () async {
    expect(
      offered(await run(const Ok(ConfidentialSepaAvailability.ready))),
      isTrue,
    );
  });

  test('is not offered to a user who cannot use it', () async {
    expect(
      offered(await run(const Ok(ConfidentialSepaAvailability.unavailable))),
      isFalse,
    );
  });

  test('a network failure keeps its meaning', () async {
    final result = await run(const Err(RecipientsNetworkFailure()));

    expect(
      (result as Err<bool, FundExchangeFailure>).failure,
      isA<FundExchangeNetworkFailure>(),
    );
  });

  test('any other recipients failure is unexpected for funding', () async {
    final result = await run(const Err(RecipientsLoadFailure()));

    expect(
      (result as Err<bool, FundExchangeFailure>).failure,
      isA<FundExchangeUnexpectedFailure>(),
    );
  });
}
