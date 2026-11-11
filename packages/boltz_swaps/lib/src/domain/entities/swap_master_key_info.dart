/// What the seed viewer shows about the dedicated swap master key.
///
/// **No mnemonic.** The words are read at the moment they are drawn, by
/// `GetSwapMnemonicUsecase`, so they never sit in screen state. Never
/// round-tripped into storage.
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
