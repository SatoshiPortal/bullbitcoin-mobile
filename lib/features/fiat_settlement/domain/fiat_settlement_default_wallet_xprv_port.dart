/// Derives the account-identity xprv (the single default Bitcoin wallet) used
/// to sign npub-wide Bullnym fiat-settlement requests. Confidential material
/// stays behind this port.
abstract class FiatSettlementDefaultWalletXprvPort {
  Future<String> deriveDefaultWalletXprv();
}
