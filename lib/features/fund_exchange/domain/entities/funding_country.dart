import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';

enum FundingCountry {
  canada(
    fundingMethods: [
      FundingMethod.emailETransfer,
      FundingMethod.bankTransferWire,
      FundingMethod.onlineBillPayment,
      FundingMethod.canadaPost,
    ],
  ),
  europe(fundingMethods: [FundingMethod.sepaTransfer]),
  mexico(fundingMethods: [FundingMethod.speiTransfer]);

  final List<FundingMethod> fundingMethods;
  const FundingCountry({required this.fundingMethods});
}
