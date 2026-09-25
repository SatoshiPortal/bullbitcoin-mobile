/// What the seed viewer shows about the dedicated swap master key.
///
/// **No mnemonic.** The words used to travel in here and sit in cubit state
/// for as long as the screen lived. They are now read at the moment they are
/// drawn, by `GetSwapMnemonicUsecase`, the same sealed-display shape
/// `secrets` uses for wallet seeds — see ARCHITECTURE.md, "Sealed UI as a
/// security tool". Never round-tripped into storage.
class SwapMasterKeyInfo {
  /// The swap master key's OWN fingerprint (distinct from [walletFingerprint]).
  final String fingerprint;

  /// Fingerprint of the wallet this swap key was derived from / bound to.
  final String walletFingerprint;

  /// 'mainnet' | 'testnet'.
  final String network;

  const SwapMasterKeyInfo({
    required this.fingerprint,
    required this.walletFingerprint,
    required this.network,
  });
}
