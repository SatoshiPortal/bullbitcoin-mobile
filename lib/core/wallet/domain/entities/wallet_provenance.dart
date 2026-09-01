enum WalletProvenance {
  defaultSeed,
  defaultSeedPassphrase,
  bip85,
  importedMnemonic,
  watchOnly,
  externalSigner;

  bool get recoverableFromSeed => switch (this) {
    defaultSeed || bip85 => true,
    defaultSeedPassphrase ||
    importedMnemonic ||
    watchOnly ||
    externalSigner => false,
  };
}
