/// How a recipient address string classifies for the SP send flow. Single
/// source of truth so the send cubit (which picks the recipient type and runs
/// the wrong-network check) and the recipient badge (which labels the input)
/// cannot disagree.
enum SpAddressKind {
  /// Mainnet silent payment (`sp1...`).
  silentPaymentMainnet,

  /// Testnet/regtest silent payment (`tsp1...`).
  silentPaymentTestnet,

  /// A standard bitcoin address (bech32 or legacy).
  bitcoin,

  /// Nothing we recognize.
  unrecognized;

  bool get isSilentPayment =>
      this == silentPaymentMainnet || this == silentPaymentTestnet;
}

/// Classify [input] by its address prefix. Prefix-only: full checksum/format
/// validation is deferred to the Rust side at prepare time.
SpAddressKind classifySpAddress(String input) {
  final lower = input.trim().toLowerCase();
  if (lower.startsWith('sp1')) return SpAddressKind.silentPaymentMainnet;
  if (lower.startsWith('tsp1')) return SpAddressKind.silentPaymentTestnet;
  if (lower.startsWith('bc1') ||
      lower.startsWith('tb1') ||
      lower.startsWith('1') ||
      lower.startsWith('m') ||
      lower.startsWith('n')) {
    return SpAddressKind.bitcoin;
  }
  return SpAddressKind.unrecognized;
}
