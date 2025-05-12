enum OldStorageKeys {
  securityKey('securityKey'),
  seeds('seeds'),
  wallets('wallets'),
  settings('settings'),
  network('network'),
  networkFees('networkFees'),
  currency('currency'),
  lighting('lighting'),
  swapTxSensitive('swapTxSensitive'),
  hiveEncryption('hiveEncryptionKey'),
  version('version'),
  payjoin('payjoin');

  final String name;
  const OldStorageKeys(this.name);
}
