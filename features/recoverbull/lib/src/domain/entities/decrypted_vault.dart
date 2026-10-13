/// Decrypted vault values. Serialization stays at the data boundary.
final class DecryptedVault {
  static const _unchanged = Object();
  final List<String> mnemonic;
  final String masterFingerprint;
  final bool isEncryptedVaultTested;
  final bool isPhysicalBackupTested;
  final DateTime? latestEncryptedBackup;
  final DateTime? latestPhysicalBackup;

  DecryptedVault({
    List<String> mnemonic = const [],
    this.masterFingerprint = '',
    this.isEncryptedVaultTested = false,
    this.isPhysicalBackupTested = false,
    this.latestEncryptedBackup,
    this.latestPhysicalBackup,
  }) : mnemonic = List.unmodifiable(mnemonic);

  DecryptedVault copyWith({
    List<String>? mnemonic,
    String? masterFingerprint,
    bool? isEncryptedVaultTested,
    bool? isPhysicalBackupTested,
    Object? latestEncryptedBackup = _unchanged,
    Object? latestPhysicalBackup = _unchanged,
  }) => DecryptedVault(
    mnemonic: mnemonic ?? this.mnemonic,
    masterFingerprint: masterFingerprint ?? this.masterFingerprint,
    isEncryptedVaultTested:
        isEncryptedVaultTested ?? this.isEncryptedVaultTested,
    isPhysicalBackupTested:
        isPhysicalBackupTested ?? this.isPhysicalBackupTested,
    latestEncryptedBackup: identical(latestEncryptedBackup, _unchanged)
        ? this.latestEncryptedBackup
        : latestEncryptedBackup as DateTime?,
    latestPhysicalBackup: identical(latestPhysicalBackup, _unchanged)
        ? this.latestPhysicalBackup
        : latestPhysicalBackup as DateTime?,
  );

  @override
  bool operator ==(Object other) =>
      other is DecryptedVault &&
      mnemonic.length == other.mnemonic.length &&
      Iterable<int>.generate(
        mnemonic.length,
      ).every((i) => mnemonic[i] == other.mnemonic[i]) &&
      masterFingerprint == other.masterFingerprint &&
      isEncryptedVaultTested == other.isEncryptedVaultTested &&
      isPhysicalBackupTested == other.isPhysicalBackupTested &&
      latestEncryptedBackup == other.latestEncryptedBackup &&
      latestPhysicalBackup == other.latestPhysicalBackup;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(mnemonic),
    masterFingerprint,
    isEncryptedVaultTested,
    isPhysicalBackupTested,
    latestEncryptedBackup,
    latestPhysicalBackup,
  );

  @override
  String toString() => 'DecryptedVault(<redacted>)';
}
