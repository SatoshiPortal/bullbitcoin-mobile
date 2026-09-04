enum WalletProvenance {
  defaultSeed,
  defaultSeedPassphrase,
  bip85,
  importedMnemonic,
  watchOnly,
  externalSigner,

  /// A wallet imported from a descriptor with its own signer roster (multi-
  /// signature, Miniscript, BullVault). Recovered from the definitions section
  /// with per-key signers, never from a seed.
  descriptor;

  bool get recoverableFromSeed => switch (this) {
    defaultSeed || bip85 => true,
    defaultSeedPassphrase ||
    importedMnemonic ||
    watchOnly ||
    externalSigner ||
    descriptor => false,
  };

  /// Whether the wallet is backed up as a definition (descriptor + signers)
  /// rather than as a seed-derived manifest entry.
  bool get backedUpAsDefinition => switch (this) {
    watchOnly || externalSigner || descriptor => true,
    defaultSeed || defaultSeedPassphrase || bip85 || importedMnemonic => false,
  };
}
