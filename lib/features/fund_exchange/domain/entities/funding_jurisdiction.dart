import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';

enum FundingJurisdiction {
  canada(
    'CA',
    fundingMethods: [
      FundingMethod.emailETransfer,
      FundingMethod.bankTransferWire,
      FundingMethod.onlineBillPayment,
      FundingMethod.canadaPost,
    ],
  ),
  europe('EU', fundingMethods: [FundingMethod.sepaTransfer]),
  mexico('MX', fundingMethods: [FundingMethod.speiTransfer]),
  costaRica(
    'CR',
    fundingMethods: [FundingMethod.crIbanCrc, FundingMethod.crIbanUsd],
  ),
  argentina('AR', fundingMethods: [FundingMethod.arsBankTransfer]);

  final String code;
  final List<FundingMethod> fundingMethods;
  const FundingJurisdiction(this.code, {required this.fundingMethods});
}
