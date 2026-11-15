/// The fiat currencies the price service quotes.
enum SupportedCurrency {
  usd('USD', 'US'),
  cad('CAD', 'CA'),
  mxn('MXN', 'MX'),
  crc('CRC', 'CR'),
  eur('EUR', 'EU'),
  ars('ARS', 'AR'),
  cop('COP', 'CO');

  final String code;

  /// Two-letter region of the currency (ISO 3166-1, `EU` for the euro).
  final String region;

  const SupportedCurrency(this.code, this.region);

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
