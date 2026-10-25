/// Outcome of verifying a stored transaction's wallet-owned input
/// signatures (GHSA-6jp4-8v48-cc5v guard).
enum TransactionSignatureStatus {
  /// Every verifiable wallet-owned input carries a valid SIGHASH_ALL
  /// signature over the transaction as stored.
  valid,

  /// At least one wallet-owned input signature fails verification: the
  /// transaction cannot have been produced by this wallet's keys and was
  /// most likely planted by the connected Electrum server.
  invalid,

  /// Verification could not be performed — the transaction or its prevouts
  /// are missing from the local store. Not evidence of manipulation, but
  /// the transaction cannot be trusted either.
  unverifiable,
}
