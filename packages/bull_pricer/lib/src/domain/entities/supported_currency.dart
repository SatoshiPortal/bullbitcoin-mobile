/// The fiat currencies the price service quotes.
enum SupportedCurrency {
  usd('USD', 'US', 2),
  cad('CAD', 'CA', 2),
  mxn('MXN', 'MX', 2),
  crc('CRC', 'CR', 2),
  eur('EUR', 'EU', 2),
  ars('ARS', 'AR', 2),
  cop('COP', 'CO', 0);

  final String code;

  /// Two-letter region of the currency (ISO 3166-1, `EU` for the euro).
  final String region;

  /// The precision used by the wallet for this supported currency.
  final int decimals;

  const SupportedCurrency(this.code, this.region, this.decimals);

  /// The flag emoji of [region].
  String get flag => String.fromCharCodes([
    for (final unit in region.codeUnits) 0x1F1E6 + unit - 0x41,
  ]);

  static final List<String> codes = List.unmodifiable([
    for (final currency in values) currency.code,
  ]);

  static SupportedCurrency? tryFromCode(String code) {
    final upper = code.toUpperCase();
    for (final currency in values) {
      if (currency.code == upper) return currency;
    }
    return null;
  }
}
