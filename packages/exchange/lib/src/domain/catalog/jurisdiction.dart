/// The legal area an exchange market, payout rail or funding rail belongs to.
enum Jurisdiction {
  canada('CA'),
  europe('EU'),
  mexico('MX'),
  costaRica('CR'),
  argentina('AR'),
  colombia('CO');

  const Jurisdiction(this.code);

  /// The code the API and the recipient types use.
  final String code;
}
