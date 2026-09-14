import 'package:bb_mobile/features/fund_exchange/application/ports/funding_gateway_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_institution.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class ListFundingInstitutionsQuery {
  final FundingJurisdiction jurisdiction;

  const ListFundingInstitutionsQuery({required this.jurisdiction});
}

class ListFundingInstitutionsResult {
  final List<FundingInstitution> institutions;

  const ListFundingInstitutionsResult({required this.institutions});
}

class ListFundingInstitutionsUsecase {
  final FundingGatewayPort _fundingGateway;

  const ListFundingInstitutionsUsecase({required this._fundingGateway});

  @useResult
  Future<Result<ListFundingInstitutionsResult, FundExchangeFailure>> execute(
    ListFundingInstitutionsQuery query,
  ) async {
    final result = await _fundingGateway.listInstitutions(
      jurisdiction: query.jurisdiction,
    );

    return result.map(
      (institutions) =>
          ListFundingInstitutionsResult(institutions: institutions),
    );
  }
}
