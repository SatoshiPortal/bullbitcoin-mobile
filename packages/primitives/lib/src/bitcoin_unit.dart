enum BitcoinUnit {
  btc(code: 'BTC', decimals: 8),
  sats(code: 'sats', decimals: 0);

  final String code;
  final int decimals;

  const BitcoinUnit({required this.code, required this.decimals});

  factory BitcoinUnit.fromName(String name) {
    return BitcoinUnit.values.firstWhere(
      (bitcoinUnit) => bitcoinUnit.name == name,
    );
  }
  factory BitcoinUnit.fromCode(String code) {
    return BitcoinUnit.values.firstWhere(
      (bitcoinUnit) => bitcoinUnit.code == code,
    );
  }
}
