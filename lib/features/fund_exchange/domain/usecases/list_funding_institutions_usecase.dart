import 'package:bb_mobile/features/fund_exchange/domain/repositories/funding_repository.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_institution.dart';
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
  final FundingRepository _fundingRepository;

  const ListFundingInstitutionsUsecase({required this._fundingRepository});

  @useResult
  Future<Result<ListFundingInstitutionsResult, FundExchangeFailure>> execute(
    ListFundingInstitutionsQuery query,
  ) async {
    final result = await _fundingRepository.listInstitutions(
      jurisdiction: query.jurisdiction,
    );

    return result.map(
      (institutions) =>
          ListFundingInstitutionsResult(institutions: institutions),
    );
  }
}
