import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/funding/domain/fund_exchange_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../map_funding_failure.dart';

class ListFundingInstitutionsQuery {
  final FundingJurisdiction jurisdiction;

  const ListFundingInstitutionsQuery({required this.jurisdiction});
}

class ListFundingInstitutionsResult {
  final List<FundingInstitution> institutions;

  const ListFundingInstitutionsResult({required this.institutions});
}

class ListFundingInstitutionsUsecase {
  final ExchangeFunding _funding;

  const ListFundingInstitutionsUsecase({required this._funding});

  @useResult
  Future<Result<ListFundingInstitutionsResult, FundExchangeFailure>> execute(
    ListFundingInstitutionsQuery query,
  ) async {
    final result = (await _funding.listInstitutions(
      jurisdiction: query.jurisdiction,
    )).mapErr(mapFundingFailure);

    return result.map(
      (institutions) =>
          ListFundingInstitutionsResult(institutions: institutions),
    );
  }
}
