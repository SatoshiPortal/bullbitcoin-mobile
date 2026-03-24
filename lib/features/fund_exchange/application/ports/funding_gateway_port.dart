import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';

abstract class FundingGatewayPort {
  Future<List<FundingInstitution>> listInstitutions({
    required FundingJurisdiction jurisdiction,
  });
  Future<FundingDetails> getFundingDetails({
    required FundingMethod fundingMethod,
  });
  Future<void> registerResponsibilityConsent();
}
