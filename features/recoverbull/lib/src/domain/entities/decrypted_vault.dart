import 'package:freezed_annotation/freezed_annotation.dart';

part 'decrypted_vault.freezed.dart';
part 'decrypted_vault.g.dart';

@Freezed(toStringOverride: false)
abstract class DecryptedVault with _$DecryptedVault {
  const factory DecryptedVault({
    @Default([]) List<String> mnemonic,
    // TODO(azad): masterFingerprint should be computed from mnemonic
    @Default('') String masterFingerprint,
    @Default(false) bool isEncryptedVaultTested,
    @Default(false) bool isPhysicalBackupTested,
    DateTime? latestEncryptedBackup,
    DateTime? latestPhysicalBackup,
  }) = _DecryptedVault;

  factory DecryptedVault.fromJson(Map<String, dynamic> json) =>
      _$DecryptedVaultFromJson(json);

  @override
  String toString() => 'DecryptedVault(<redacted>)';
}
