enum FiatCurrency {
  usd(
    code: 'USD',
    displayName: 'US Dollar',
    jurisdiction: 'United States',
    flag: '🇺🇸',
  ),
  cad(
    code: 'CAD',
    displayName: 'Canadian Dollar',
    jurisdiction: 'Canada',
    flag: '🇨🇦',
  ),
  mxn(
    code: 'MXN',
    displayName: 'Mexican Peso',
    jurisdiction: 'Mexico',
    flag: '🇲🇽',
  ),
  crc(
    code: 'CRC',
    displayName: 'Costa Rican Colón',
    jurisdiction: 'Costa Rica',
    flag: '🇨🇷',
  ),
  eur(code: 'EUR', displayName: 'Euro', jurisdiction: 'Europe', flag: '🇪🇺'),
  ars(
    code: 'ARS',
    displayName: 'Argentine Peso',
    jurisdiction: 'Argentina',
    flag: '🇦🇷',
  ),
  cop(
    code: 'COP',
    displayName: 'Colombian Peso',
    jurisdiction: 'Colombia',
    flag: '🇨🇴',
  );

  final String code;
  final String displayName;
  final String jurisdiction;
  final String flag;
  const FiatCurrency({
    required this.code,
    required this.displayName,
    required this.jurisdiction,
    required this.flag,
  });
}
