import 'package:bb_mobile/features/fund_exchange/application/ports/funding_gateway_port.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/get_funding_details_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/list_funding_institutions_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/register_responsibility_consent_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _rawReason =
    'DioException [bad response]: {"error":{"data":{"apiError":'
    '{"en":"Recipient DE89370400440532013000 is not configured"}}}}';

void main() {
  group('GetFundingDetailsUsecase', () {
    test('forwards the gateway failure unchanged', () async {
      final usecase = GetFundingDetailsUsecase(
        fundingGateway: _FakeFundingGateway(
          detailsResult: const Err(
            FundExchangeKycIncompleteFailure(_rawReason),
          ),
        ),
      );

      final result = await usecase.execute(const GetRegularSepaDetails());

      expect(result, isA<Err<GetFundingDetailsResult, FundExchangeFailure>>());
      expect((result as Err).failure, isA<FundExchangeKycIncompleteFailure>());
    });

    test('never throws for a failing gateway', () async {
      final usecase = GetFundingDetailsUsecase(
        fundingGateway: _FakeFundingGateway(
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
        fundingGateway: _FakeFundingGateway(detailsResult: const Ok(details)),
      );

      final result = await usecase.execute(
        const GetCopBankTransferDetails(bankCode: 'BC01', amountCop: 100000),
      );

      expect((result as Ok).value.fundingDetails, details);
    });
  });

  group('ListFundingInstitutionsUsecase', () {
    test('forwards the gateway failure unchanged', () async {
      final usecase = ListFundingInstitutionsUsecase(
        fundingGateway: _FakeFundingGateway(
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

      expect((result as Err).failure, isA<FundExchangeNoInstitutionsFailure>());
    });

    test('wraps a successful payload', () async {
      final institution = FundingInstitution.create(
        code: 'BC01',
        name: 'Bancolombia',
      );
      final usecase = ListFundingInstitutionsUsecase(
        fundingGateway: _FakeFundingGateway(
          institutionsResult: Ok([institution]),
        ),
      );

      final result = await usecase.execute(
        const ListFundingInstitutionsQuery(
          jurisdiction: FundingJurisdiction.colombia,
        ),
      );

      expect((result as Ok).value.institutions, [institution]);
    });
  });

  group('RegisterResponsibilityConsentUsecase', () {
    test('forwards the gateway failure unchanged', () async {
      final usecase = RegisterResponsibilityConsentUsecase(
        fundingGateway: _FakeFundingGateway(
          consentResult: const Err(
            FundExchangeConsentRegistrationFailure(_rawReason),
          ),
        ),
      );

      final result = await usecase.execute(
        const RegisterResponsibilityConsentCommand(),
      );

      expect(
        (result as Err).failure,
        isA<FundExchangeConsentRegistrationFailure>(),
      );
    });

    test('wraps success', () async {
      final usecase = RegisterResponsibilityConsentUsecase(
        fundingGateway: _FakeFundingGateway(consentResult: const Ok(null)),
      );

      expect(
        await usecase.execute(const RegisterResponsibilityConsentCommand()),
        isA<Ok<RegisterResponsibilityConsentResult, FundExchangeFailure>>(),
      );
    });
  });
}

class _FakeFundingGateway implements FundingGatewayPort {
  final Result<FundingDetails, FundExchangeFailure>? detailsResult;
  final Result<List<FundingInstitution>, FundExchangeFailure>?
  institutionsResult;
  final Result<void, FundExchangeFailure>? consentResult;

  _FakeFundingGateway({
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
