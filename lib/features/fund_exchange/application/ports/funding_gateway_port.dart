import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

abstract class FundingGatewayPort {
  @useResult
  Future<Result<List<FundingInstitution>, FundExchangeFailure>>
  listInstitutions({required FundingJurisdiction jurisdiction});

  @useResult
  Future<Result<FundingDetails, FundExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  });

  @useResult
  Future<Result<void, FundExchangeFailure>> registerResponsibilityConsent();
}
