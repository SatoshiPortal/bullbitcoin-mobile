/// Wire representation of the existing decrypted vault payload.
final class DecryptedVaultModel {
  final List<String> mnemonic;
  final String masterFingerprint;
  final bool isEncryptedVaultTested;
  final bool isPhysicalBackupTested;
  final DateTime? latestEncryptedBackup;
  final DateTime? latestPhysicalBackup;

  const DecryptedVaultModel({
    this.mnemonic = const [],
    this.masterFingerprint = '',
    this.isEncryptedVaultTested = false,
    this.isPhysicalBackupTested = false,
    this.latestEncryptedBackup,
    this.latestPhysicalBackup,
  });

  factory DecryptedVaultModel.fromMap(Map<String, dynamic> map) {
    final mnemonic = map['mnemonic'];
    final fingerprint = map['masterFingerprint'];
    final encryptedTested = map['isEncryptedVaultTested'];
    final physicalTested = map['isPhysicalBackupTested'];
    if ((mnemonic != null &&
            (mnemonic is! List || mnemonic.any((word) => word is! String))) ||
        (fingerprint != null && fingerprint is! String) ||
        (encryptedTested != null && encryptedTested is! bool) ||
        (physicalTested != null && physicalTested is! bool)) {
      throw const FormatException('Invalid decrypted vault fields');
    }
    DateTime? date(String key) {
      final value = map[key];
      if (value == null) return null;
      if (value is! String) {
        throw const FormatException('Invalid vault timestamp');
      }
      return DateTime.parse(value);
    }

    return DecryptedVaultModel(
      mnemonic: mnemonic == null ? const [] : (mnemonic as List).cast<String>(),
      masterFingerprint: fingerprint as String? ?? '',
      isEncryptedVaultTested: encryptedTested as bool? ?? false,
      isPhysicalBackupTested: physicalTested as bool? ?? false,
      latestEncryptedBackup: date('latestEncryptedBackup'),
      latestPhysicalBackup: date('latestPhysicalBackup'),
    );
  }

  Map<String, dynamic> toMap() => {
    'mnemonic': mnemonic,
    'masterFingerprint': masterFingerprint,
    'isEncryptedVaultTested': isEncryptedVaultTested,
    'isPhysicalBackupTested': isPhysicalBackupTested,
    'latestEncryptedBackup': latestEncryptedBackup?.toIso8601String(),
    'latestPhysicalBackup': latestPhysicalBackup?.toIso8601String(),
  };
}
