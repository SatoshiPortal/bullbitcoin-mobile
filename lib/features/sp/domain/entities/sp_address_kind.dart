/// How a recipient address string classifies for the SP send flow. Single
/// source of truth so `SpAddress` (which picks the recipient type and runs the
/// wrong-network check) and the recipient badge (which labels the input)
/// cannot disagree.
enum SpAddressKind {
  /// Mainnet silent payment (`sp1...`).
  silentPaymentMainnet,

  /// Testnet/signet silent payment (`tsp1...`, the hrp shared by both).
  silentPaymentTestnet,

  /// Regtest silent payment (`sprt1...`).
  silentPaymentRegtest,

  /// Mainnet bitcoin address (`bc1...`, `1...`, `3...`).
  bitcoinMainnet,

  /// Testnet/signet bech32 bitcoin address (`tb1...`, the hrp shared by both).
  bitcoinTestnet,

  /// Regtest bech32 bitcoin address (`bcrt1...`).
  bitcoinRegtest,

  /// Legacy bitcoin address outside mainnet (`m...`, `n...`, `2...`). Regtest
  /// reuses testnet's base58 version bytes, so the prefix cannot tell the two
  /// apart and every non-mainnet network is allowed.
  bitcoinLegacyNonMainnet,

  /// Nothing we recognize.
  unrecognized;

  bool get isSilentPayment =>
      this == silentPaymentMainnet ||
      this == silentPaymentTestnet ||
      this == silentPaymentRegtest;

  bool get isBitcoin =>
      this == bitcoinMainnet ||
      this == bitcoinTestnet ||
      this == bitcoinRegtest ||
      this == bitcoinLegacyNonMainnet;
}
