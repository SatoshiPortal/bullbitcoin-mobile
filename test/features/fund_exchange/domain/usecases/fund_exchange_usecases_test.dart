import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/get_funding_details_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/list_funding_institutions_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/register_responsibility_consent_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../result_helpers.dart';

const _rawReason =
    'DioException [bad response]: {"error":{"data":{"apiError":'
    '{"en":"Recipient DE89370400440532013000 is not configured"}}}}';

void main() {
  group('GetFundingDetailsUsecase', () {
    test('forwards the repository failure unchanged', () async {
      final usecase = GetFundingDetailsUsecase(
        funding: _FakeFundingRepository(
          detailsResult: const Err(
            ExchangeFundingFailure(
              ExchangeFundingProblem.kycIncomplete,
              _rawReason,
            ),
          ),
        ),
      );

      final result = await usecase.execute(const GetRegularSepaDetails());

      expect(result, isA<Err<GetFundingDetailsResult, FundExchangeFailure>>());
      expect(failureOf(result), isA<FundExchangeKycIncompleteFailure>());
    });

    test('never throws for a failing repository', () async {
      final usecase = GetFundingDetailsUsecase(
        funding: _FakeFundingRepository(
          detailsResult: const Err(ExchangeUnexpectedFailure(_rawReason)),
        ),
      );

      await expectLater(
        usecase.execute(
          const GetCopBankTransferDetails(bankCode: 'BC01', amountCop: 100000),
        ),
        completes,
      );
    });

    test('wraps a successful payload', () async {
      const details = CopBankTransferFundingDetails(
        paymentLink: 'https://pay.example/abc',
      );
      final usecase = GetFundingDetailsUsecase(
        funding: _FakeFundingRepository(detailsResult: const Ok(details)),
      );

      final result = await usecase.execute(
        const GetCopBankTransferDetails(bankCode: 'BC01', amountCop: 100000),
      );

      expect(valueOf(result).fundingDetails, details);
    });
  });

  group('ListFundingInstitutionsUsecase', () {
    test('forwards the repository failure unchanged', () async {
      final usecase = ListFundingInstitutionsUsecase(
        funding: _FakeFundingRepository(
          institutionsResult: const Err(
            ExchangeFundingFailure(
              ExchangeFundingProblem.noInstitutions,
              _rawReason,
            ),
          ),
        ),
      );

      final result = await usecase.execute(
        const ListFundingInstitutionsQuery(
          jurisdiction: FundingJurisdiction.colombia,
        ),
      );

      expect(failureOf(result), isA<FundExchangeNoInstitutionsFailure>());
    });

    test('wraps a successful payload', () async {
      final institution = FundingInstitution.create(
        code: 'BC01',
        name: 'Bancolombia',
      );
      final usecase = ListFundingInstitutionsUsecase(
        funding: _FakeFundingRepository(institutionsResult: Ok([institution])),
      );

      final result = await usecase.execute(
        const ListFundingInstitutionsQuery(
          jurisdiction: FundingJurisdiction.colombia,
        ),
      );

      expect(valueOf(result).institutions, [institution]);
    });
  });

  group('RegisterResponsibilityConsentUsecase', () {
    test('forwards the repository failure unchanged', () async {
      final usecase = RegisterResponsibilityConsentUsecase(
        funding: _FakeFundingRepository(
          consentResult: const Err(
            ExchangeConsentRegistrationFailure(_rawReason),
          ),
        ),
      );

      final result = await usecase.execute(
        const RegisterResponsibilityConsentCommand(),
      );

      expect(failureOf(result), isA<FundExchangeConsentRegistrationFailure>());
    });

    test('wraps success', () async {
      final usecase = RegisterResponsibilityConsentUsecase(
        funding: _FakeFundingRepository(consentResult: const Ok(null)),
      );

      expect(
        await usecase.execute(const RegisterResponsibilityConsentCommand()),
        isA<Ok<RegisterResponsibilityConsentResult, FundExchangeFailure>>(),
      );
    });
  });
}

class _FakeFundingRepository implements ExchangeFunding {
  final Result<FundingDetails, ExchangeFailure>? detailsResult;
  final Result<List<FundingInstitution>, ExchangeFailure>? institutionsResult;
  final Result<void, ExchangeFailure>? consentResult;

  _FakeFundingRepository({
    this.detailsResult,
    this.institutionsResult,
    this.consentResult,
  });

  @override
  Future<Result<FundingDetails, ExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  }) async => detailsResult!;

  @override
  Future<Result<List<FundingInstitution>, ExchangeFailure>> listInstitutions({
    required FundingJurisdiction jurisdiction,
  }) async => institutionsResult!;

  @override
  Future<Result<void, ExchangeFailure>> registerResponsibilityConsent() async =>
      consentResult!;
}
