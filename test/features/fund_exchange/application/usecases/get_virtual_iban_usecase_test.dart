import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/fund_exchange/application/fund_exchange_application_error.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/get_virtual_iban_usecase.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecipientsFacade extends Mock implements RecipientsFacade {}

void main() {
  late _MockRecipientsFacade facade;
  late GetVirtualIbanUsecase usecase;

  setUp(() {
    facade = _MockRecipientsFacade();
    usecase = GetVirtualIbanUsecase(recipientsFacade: facade);
  });

  void mockFirstEmission(Result<VirtualIban, RecipientsFailure> result) {
    when(
      () => facade.watchVirtualIbanActivation(createIfAbsent: false),
    ).thenAnswer((_) => Stream.value(result));
  }

  test('returns the virtual IBAN from the first emission', () async {
    const virtualIban = VirtualIban(
      status: VirtualIbanStatus.active,
      iban: 'DE89370400440532013000',
      bicCode: 'TESTBIC',
      bankAddress: 'Test bank',
      ibanCountry: 'DE',
    );
    mockFirstEmission(const Ok(virtualIban));

    final result = await usecase.execute();

    expect(result, virtualIban);
  });

  test('maps the not-available failure to the PO404 api error', () async {
    mockFirstEmission(const Err(VirtualIbanNotAvailableFailure('denied')));

    await expectLater(
      usecase.execute(),
      throwsA(
        isA<FetchFundingDetailsFailed>().having(
          (e) => e.code,
          'code',
          'ERR_RCP_PO404',
        ),
      ),
    );
  });

  test('maps the EU residency failure to the RCP400 api error', () async {
    mockFirstEmission(
      const Err(VirtualIbanEuResidencyRequiredFailure('EU only')),
    );

    await expectLater(
      usecase.execute(),
      throwsA(
        isA<FetchFundingDetailsFailed>()
            .having((e) => e.code, 'code', 'ERR_RCP_400')
            .having((e) => e.message, 'message', 'EU only'),
      ),
    );
  });

  test('maps any other failure to a generic fetch error', () async {
    mockFirstEmission(const Err(VirtualIbanFailure('boom')));

    await expectLater(
      usecase.execute(),
      throwsA(
        isA<FetchFundingDetailsFailed>().having((e) => e.code, 'code', isNull),
      ),
    );
  });
}
