import 'package:bb_mobile/features/fund_exchange/application/fund_exchange_application_errors.dart';
import 'package:bb_mobile/features/fund_exchange/application/ports/funding_gateway_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_domain_errors.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_institution.dart';

class ListFundingInstitutionsQuery {
  final String jurisdictionCode;

  const ListFundingInstitutionsQuery({required this.jurisdictionCode});
}

class ListFundingInstitutionsResult {
  final List<FundingInstitution> institutions;

  const ListFundingInstitutionsResult({required this.institutions});
}

class ListFundingInstitutionsUsecase {
  final FundingGatewayPort _fundingGateway;

  const ListFundingInstitutionsUsecase({
    required FundingGatewayPort fundingGateway,
  }) : _fundingGateway = fundingGateway;

  Future<ListFundingInstitutionsResult> execute(
    ListFundingInstitutionsQuery query,
  ) async {
    try {
      final jurisdiction = FundingJurisdiction.fromString(
        query.jurisdictionCode,
      );

      final institutions = await _fundingGateway.listInstitutions(
        jurisdiction: jurisdiction,
      );

      return ListFundingInstitutionsResult(institutions: institutions);
    } on FundExchangeDomainError catch (e) {
      throw FundExchangeApplicationError.fromDomainError(e);
    } on FundExchangeApplicationError {
      rethrow;
    } catch (e) {
      throw FundExchangeUnknownError(message: '$e');
    }
  }
}
