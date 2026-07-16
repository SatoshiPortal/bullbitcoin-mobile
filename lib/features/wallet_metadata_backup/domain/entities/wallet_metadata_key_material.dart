final class WalletMetadataKeyMaterial {
  final String xprvBase58;
  final String parentFingerprint;

  WalletMetadataKeyMaterial({
    required this.xprvBase58,
    required String parentFingerprint,
  }) : parentFingerprint = parentFingerprint.toLowerCase() {
    if (xprvBase58.isEmpty || xprvBase58.length > 256) {
      throw ArgumentError.value(xprvBase58.length, 'xprvBase58');
    }
    if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(this.parentFingerprint)) {
      throw ArgumentError.value(parentFingerprint, 'parentFingerprint');
    }
  }
}
