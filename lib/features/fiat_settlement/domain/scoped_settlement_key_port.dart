/// Availability and confidential access to the locally stored scoped
/// `SELL_TO_FIAT_BALANCE` credential.
///
/// [isPresent] is the only signal exposed to gating/UI. [readPlaintext] returns
/// the raw key and MUST be called from nowhere except the final set-fiat
/// operation, immediately before handing the value to the Bullnym transport.
abstract interface class ScopedSettlementKeyPort {
  Future<bool> isPresent();

  /// Plaintext scoped key for the current environment, or null when absent.
  Future<String?> readPlaintext();
}
