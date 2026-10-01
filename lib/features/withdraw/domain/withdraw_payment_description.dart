class WithdrawPaymentDescription {
  static const minLength = 5;
  static const _riskyWords = [
    'bitcoin',
    'btc',
    'sats',
    'cripto',
    'crypto',
    'bit',
  ];

  static final _riskyWordsPattern = RegExp(
    '\\b(${_riskyWords.map(RegExp.escape).join('|')})\\b',
    caseSensitive: false,
  );

  static String sanitize(String value) => value
      .replaceAll(_riskyWordsPattern, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool isValid(String value) =>
      value.isEmpty || value.length >= minLength;

  const WithdrawPaymentDescription._();
}
