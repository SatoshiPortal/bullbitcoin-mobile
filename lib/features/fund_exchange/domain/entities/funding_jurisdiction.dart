enum FundingJurisdiction {
  canada('CA'),
  europe('EU'),
  mexico('MX'),
  costaRica('CR'),
  argentina('AR'),
  colombia('CO');

  final String code;

  const FundingJurisdiction(this.code);
}
