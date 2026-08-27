/// Display/management view of the dedicated swap master key (the "swap
/// mnemonic"), surfaced in the seed viewer so a super-user can inspect and
/// delete it. Carries only what the UI needs — never round-tripped into
/// storage.
class SwapMasterKeyInfo {
  /// The swap mnemonic words (space-joined).
  final String mnemonic;

  /// The swap master key's OWN fingerprint (distinct from [walletFingerprint]).
  final String fingerprint;

  /// Fingerprint of the wallet this swap key was derived from / bound to.
  final String walletFingerprint;

  /// 'mainnet' | 'testnet'.
  final String network;

  const SwapMasterKeyInfo({
    required this.mnemonic,
    required this.fingerprint,
    required this.walletFingerprint,
    required this.network,
  });
}
