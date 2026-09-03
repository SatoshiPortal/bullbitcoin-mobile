final class WalletDescriptorKey {
  final String id;
  final String signerId;
  final String masterFingerprint;
  final String xpubFingerprint;
  final String xpub;
  final String? derivationPath;
  final String descriptorPath;
  final bool requiresPassphrase;

  WalletDescriptorKey({
    required this.id,
    required this.signerId,
    required this.masterFingerprint,
    required this.xpubFingerprint,
    required this.xpub,
    this.derivationPath,
    this.descriptorPath = '',
    this.requiresPassphrase = false,
  }) {
    if (id.trim().isEmpty) throw ArgumentError.value(id, 'id');
    if (signerId.trim().isEmpty) {
      throw ArgumentError.value(signerId, 'signerId');
    }
    if (masterFingerprint.trim().isEmpty &&
        xpubFingerprint.trim().isEmpty &&
        xpub.trim().isEmpty) {
      throw ArgumentError(
        'Wallet descriptor key requires a fingerprint or extended public key',
      );
    }
  }

  WalletDescriptorKey copyWith({
    String? id,
    String? signerId,
    String? masterFingerprint,
    String? derivationPath,
    bool? requiresPassphrase,
  }) => WalletDescriptorKey(
    id: id ?? this.id,
    signerId: signerId ?? this.signerId,
    masterFingerprint: masterFingerprint ?? this.masterFingerprint,
    xpubFingerprint: xpubFingerprint,
    xpub: xpub,
    derivationPath: derivationPath ?? this.derivationPath,
    descriptorPath: descriptorPath,
    requiresPassphrase: requiresPassphrase ?? this.requiresPassphrase,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletDescriptorKey &&
          id == other.id &&
          signerId == other.signerId &&
          masterFingerprint == other.masterFingerprint &&
          xpubFingerprint == other.xpubFingerprint &&
          xpub == other.xpub &&
          derivationPath == other.derivationPath &&
          descriptorPath == other.descriptorPath &&
          requiresPassphrase == other.requiresPassphrase;

  @override
  int get hashCode => Object.hash(
    id,
    signerId,
    masterFingerprint,
    xpubFingerprint,
    xpub,
    derivationPath,
    descriptorPath,
    requiresPassphrase,
  );
}
