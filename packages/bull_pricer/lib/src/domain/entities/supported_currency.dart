/// The fiat currencies the price service quotes.
enum SupportedCurrency {
  usd('USD'),
  cad('CAD'),
  mxn('MXN'),
  crc('CRC'),
  eur('EUR'),
  ars('ARS'),
  cop('COP');

  final String code;

  const SupportedCurrency(this.code);

  static SupportedCurrency? tryFromCode(String code) {
    final upper = code.toUpperCase();
    for (final currency in values) {
      if (currency.code == upper) return currency;
    }
    return null;
  }
}
