/// A swap master key already derived from the default bitcoin wallet by the
/// app's secrets layer. The engine stores and signs with it; it never sees
/// the wallet's own mnemonic.
class DerivedSwapMasterKey {
  final String walletFingerprint;
  final String xprv;
  final String xpub;
  final String mnemonic;
  final String fingerprint;
  final bool isTestnet;

  const DerivedSwapMasterKey({
    required this.walletFingerprint,
    required this.xprv,
    required this.xpub,
    required this.mnemonic,
    required this.fingerprint,
    required this.isTestnet,
  });

  @override
  String toString() =>
      'DerivedSwapMasterKey($fingerprint, wallet $walletFingerprint, •••)';
}
