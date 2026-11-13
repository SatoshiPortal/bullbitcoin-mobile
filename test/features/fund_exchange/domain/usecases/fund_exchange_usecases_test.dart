import 'package:bb_mobile/features/fund_exchange/domain/repositories/funding_repository.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/get_funding_details_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/list_funding_institutions_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/register_responsibility_consent_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
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
        fundingRepository: _FakeFundingRepository(
          detailsResult: const Err(
            FundExchangeKycIncompleteFailure(_rawReason),
          ),
        ),
      );

      final result = await usecase.execute(const GetRegularSepaDetails());

      expect(result, isA<Err<GetFundingDetailsResult, FundExchangeFailure>>());
      expect(failureOf(result), isA<FundExchangeKycIncompleteFailure>());
    });

    test('never throws for a failing repository', () async {
      final usecase = GetFundingDetailsUsecase(
        fundingRepository: _FakeFundingRepository(
          detailsResult: const Err(FundExchangeUnexpectedFailure(_rawReason)),
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
        fundingRepository: _FakeFundingRepository(
          detailsResult: const Ok(details),
        ),
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
        fundingRepository: _FakeFundingRepository(
          institutionsResult: const Err(
            FundExchangeNoInstitutionsFailure(_rawReason),
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
        fundingRepository: _FakeFundingRepository(
          institutionsResult: Ok([institution]),
        ),
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
        fundingRepository: _FakeFundingRepository(
          consentResult: const Err(
            FundExchangeConsentRegistrationFailure(_rawReason),
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
        fundingRepository: _FakeFundingRepository(
          consentResult: const Ok(null),
        ),
      );

      expect(
        await usecase.execute(const RegisterResponsibilityConsentCommand()),
        isA<Ok<RegisterResponsibilityConsentResult, FundExchangeFailure>>(),
      );
    });
  });
}

class _FakeFundingRepository implements FundingRepository {
  final Result<FundingDetails, FundExchangeFailure>? detailsResult;
  final Result<List<FundingInstitution>, FundExchangeFailure>?
  institutionsResult;
  final Result<void, FundExchangeFailure>? consentResult;

  _FakeFundingRepository({
    this.detailsResult,
    this.institutionsResult,
    this.consentResult,
  });

  @override
  Future<Result<FundingDetails, FundExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  }) async => detailsResult!;

  @override
  Future<Result<List<FundingInstitution>, FundExchangeFailure>>
  listInstitutions({required FundingJurisdiction jurisdiction}) async =>
      institutionsResult!;

  @override
  Future<Result<void, FundExchangeFailure>>
  registerResponsibilityConsent() async => consentResult!;
}
