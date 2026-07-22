/// How a recipient address string classifies for the SP send flow. Single
/// source of truth so the send cubit (which picks the recipient type and runs
/// the wrong-network check) and the recipient badge (which labels the input)
/// cannot disagree.
enum SpAddressKind {
  /// Mainnet silent payment (`sp1...`).
  silentPaymentMainnet,

  /// Testnet/signet silent payment (`tsp1...`, the hrp shared by both).
  silentPaymentTestnet,

  /// Regtest silent payment (`sprt1...`).
  silentPaymentRegtest,

  /// A standard bitcoin address (bech32 or legacy).
  bitcoin,

  /// Nothing we recognize.
  unrecognized;

  bool get isSilentPayment =>
      this == silentPaymentMainnet ||
      this == silentPaymentTestnet ||
      this == silentPaymentRegtest;
}

/// Classify [input] by its address prefix. Prefix-only: full checksum/format
/// validation is deferred to the Rust side at prepare time.
SpAddressKind classifySpAddress(String input) {
  final lower = input.trim().toLowerCase();
  // Match the longer `sprt1` and `tsp1` prefixes before the shorter `sp1` so
  // the network is picked unambiguously.
  if (lower.startsWith('sprt1')) return SpAddressKind.silentPaymentRegtest;
  if (lower.startsWith('tsp1')) return SpAddressKind.silentPaymentTestnet;
  if (lower.startsWith('sp1')) return SpAddressKind.silentPaymentMainnet;
  if (lower.startsWith('bcrt1') ||
      lower.startsWith('bc1') ||
      lower.startsWith('tb1') ||
      lower.startsWith('1') ||
      lower.startsWith('2') ||
      lower.startsWith('3') ||
      lower.startsWith('m') ||
      lower.startsWith('n')) {
    return SpAddressKind.bitcoin;
  }
  return SpAddressKind.unrecognized;
}
