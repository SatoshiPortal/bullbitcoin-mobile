import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'catalog/jurisdiction.dart';
import 'entities/funding_details.dart';
import 'entities/funding_institution.dart';
import 'entities/funding_method.dart';
import 'exchange_failure.dart';

abstract interface class ExchangeFunding {
  @useResult
  Future<Result<FundingDetails, ExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  });
  @useResult
  Future<Result<List<FundingInstitution>, ExchangeFailure>> listInstitutions({
    required Jurisdiction jurisdiction,
  });
  @useResult
  Future<Result<void, ExchangeFailure>> registerResponsibilityConsent();
}

final class ExchangeFundingImpl implements ExchangeFunding {
  final Future<Result<FundingDetails, ExchangeFailure>> Function(FundingMethod)
  _get;
  final Future<Result<List<FundingInstitution>, ExchangeFailure>> Function(
    Jurisdiction,
  )
  _list;
  final Future<Result<void, ExchangeFailure>> Function() _consent;

  const ExchangeFundingImpl({
    required this._get,
    required this._list,
    required this._consent,
  });

  @override
  Future<Result<FundingDetails, ExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  }) => _get(fundingMethod);

  @override
  Future<Result<List<FundingInstitution>, ExchangeFailure>> listInstitutions({
    required Jurisdiction jurisdiction,
  }) => _list(jurisdiction);

  @override
  Future<Result<void, ExchangeFailure>> registerResponsibilityConsent() =>
      _consent();
}
