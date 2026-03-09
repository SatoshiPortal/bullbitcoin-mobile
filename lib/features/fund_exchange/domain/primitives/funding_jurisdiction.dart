import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_domain_errors.dart';

enum FundingJurisdiction {
  canada('CA'),
  europe('EU'),
  mexico('MX'),
  costaRica('CR'),
  argentina('AR'),
  colombia('CO');

  final String code;
  const FundingJurisdiction(this.code);

  static FundingJurisdiction fromString(String code) {
    return FundingJurisdiction.values.firstWhere(
      (e) => e.code == code,
      orElse: () => throw JurisdictionNotSupported(jurisdiction: code),
    );
  }
}
