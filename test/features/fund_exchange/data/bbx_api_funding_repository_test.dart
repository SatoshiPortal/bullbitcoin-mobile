import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/features/fund_exchange/data/bbx_api_funding_repository.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bbx_api/bbx_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../result_helpers.dart';

class _MockRecipientRepo extends Mock implements RecipientRepo {}

class _MockUserRepo extends Mock implements bbx.UserRepo {}

void main() {
  setUpAll(() {
    registerFallbackValue(bbx.InPaymentProcessor.inCadEmailTransferApl);
  });

  late _MockRecipientRepo recipients;
  late _MockUserRepo users;
  late BbxApiFundingRepository repository;

  setUp(() {
    recipients = _MockRecipientRepo();
    users = _MockUserRepo();
    final container = _MockBbxApi();
    when(() => container.recipients).thenReturn(recipients);
    when(() => container.users).thenReturn(users);
    repository = BbxApiFundingRepository(api: BbxApiDatasource(container));
  });

  void failFundingDetailsWith(bbx.ApiError error) {
    when(
      () => recipients.userPaymentProcessorCode(any()),
    ).thenAnswer((_) async => bbx.ApiResult.apiFailure(error: error));
  }

  test('maps each known API code to its own failure variant', () async {
    const expected = <String, Type>{
      'ERR_ORD_PO404': FundExchangePaymentOptionUnavailableFailure,
      'ERR_RCP_PO404': FundExchangeOptionNotPermittedFailure,
      'ERR_RCP_POSINPE404': FundExchangeSinpeNotRegisteredFailure,
      'ERR_ORD_KYC400': FundExchangeKycIncompleteFailure,
      'ERR_ORD_CSRCP400': FundExchangeSepaVirtualPaymentInactiveFailure,
      'ERR_RCP_400': FundExchangeRequestInvalidFailure,
      'ERR_SOMETHING_NEW': FundExchangeUnexpectedFailure,
    };

    for (final entry in expected.entries) {
      failFundingDetailsWith(
        bbx.ApiError(
          serverMessage: 'backend sentence',
          rpcErrorData: {
            'apiError': {'code': entry.key},
          },
        ),
      );

      final failure = failureOf(
        await repository.getFundingDetails(
          fundingMethod: const EmailETransfer(),
        ),
      );

      expect(failure.runtimeType, entry.value, reason: entry.key);
    }
  });

  test('sends the payment processor of the funding method', () async {
    failFundingDetailsWith(const bbx.ApiError(serverMessage: 'x'));

    final _ = await repository.getFundingDetails(fundingMethod: const Sinpe());

    verify(
      () => recipients.userPaymentProcessorCode(
        bbx.InPaymentProcessor.inCrcRdvSinpe,
      ),
    ).called(1);
  });

  test('an unreachable API is a network failure', () async {
    failFundingDetailsWith(
      const bbx.ApiError(
        serverMessage: 'Connection Time Out',
        kind: bbx.ApiErrorKind.timeout,
      ),
    );

    final failure = failureOf(
      await repository.getFundingDetails(fundingMethod: const EmailETransfer()),
    );

    expect(failure, isA<FundExchangeNetworkFailure>());
  });

  test(
    'a rejected certificate is not reported as a connection problem',
    () async {
      failFundingDetailsWith(
        const bbx.ApiError(kind: bbx.ApiErrorKind.badCertificate),
      );

      final failure = failureOf(
        await repository.getFundingDetails(
          fundingMethod: const EmailETransfer(),
        ),
      );

      expect(failure, isA<FundExchangeUnexpectedFailure>());
    },
  );

  test('details without a field the method needs are unexpected', () async {
    when(() => recipients.userPaymentProcessorCode(any())).thenAnswer(
      (_) async => bbx.ApiResult<bbx.FundingDetails>.success(
        data: bbx.FundingDetailsModel.fromResult({
          'element': {'code': 'ABC123'},
        }),
      ),
    );

    final failure = failureOf(
      await repository.getFundingDetails(fundingMethod: const EmailETransfer()),
    );

    expect(failure, isA<FundExchangeUnexpectedFailure>());
  });

  test('a missing API key is unexpected, as before', () async {
    failFundingDetailsWith(
      const bbx.ApiError(
        serverMessage: 'No API key',
        kind: bbx.ApiErrorKind.unauthenticated,
        code: 'ERR_API_KEY_MISSING',
      ),
    );

    final failure = failureOf(
      await repository.getFundingDetails(fundingMethod: const EmailETransfer()),
    );

    expect(failure, isA<FundExchangeUnexpectedFailure>());
  });

  test('maps the package funding details to the method', () async {
    when(() => recipients.userPaymentProcessorCode(any())).thenAnswer(
      (_) async => bbx.ApiResult<bbx.FundingDetails>.success(
        data: bbx.FundingDetailsModel.fromResult({
          'element': {'code': 'ABC123'},
          'ppExtraData': {
            'BENEFICIARY NAME': 'Example Payee',
            'BENEFICIARY EMAIL': 'pay@example.com',
          },
        }),
      ),
    );

    final details = valueOf(
      await repository.getFundingDetails(fundingMethod: const EmailETransfer()),
    );

    expect(details, isA<ETransferFundingDetails>());
    final eTransfer = details as ETransferFundingDetails;
    expect(eTransfer.secretQuestion, 'ABC123');
    expect(eTransfer.beneficiaryEmail, 'pay@example.com');
  });

  test('lists institutions and skips nothing usable', () async {
    when(() => recipients.listInstitutionCodesByCountryCode('co')).thenAnswer(
      (_) async => bbx.ApiResult.success(
        data: bbx.ListResponse(
          items: const [InstitutionCode(code: '001', name: 'Example Bank')],
          totalElements: 1,
        ),
      ),
    );

    final institutions = valueOf(
      await repository.listInstitutions(
        jurisdiction: FundingJurisdiction.colombia,
      ),
    );

    expect(institutions.single.code, '001');
  });

  test('an empty institution list is its own failure', () async {
    when(() => recipients.listInstitutionCodesByCountryCode('mx')).thenAnswer(
      (_) async => bbx.ApiResult.success(
        data: bbx.ListResponse<InstitutionCode>(items: [], totalElements: 0),
      ),
    );

    final failure = failureOf(
      await repository.listInstitutions(
        jurisdiction: FundingJurisdiction.mexico,
      ),
    );

    expect(failure, isA<FundExchangeNoInstitutionsFailure>());
  });

  test('a consent refused while offline is a network failure', () async {
    when(() => users.consentToScamWarning()).thenAnswer(
      (_) async => bbx.ApiResult.apiFailure(
        error: const bbx.ApiError(
          serverMessage: 'x',
          kind: bbx.ApiErrorKind.network,
        ),
      ),
    );

    final failure = failureOf(await repository.registerResponsibilityConsent());

    expect(failure, isA<FundExchangeNetworkFailure>());
  });
}

class _MockBbxApi extends Mock implements bbx.BbxApi {}
