enum WalletProvenance {
  defaultSeed,
  bip85,
  importedMnemonic,
  watchOnly,
  externalSigner;

  bool get recoverableFromSeed => switch (this) {
    defaultSeed || bip85 => true,
    importedMnemonic || watchOnly || externalSigner => false,
  };
}
