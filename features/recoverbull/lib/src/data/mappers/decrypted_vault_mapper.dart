import '../../domain/entities/decrypted_vault.dart';
import '../models/decrypted_vault_model.dart';

final class DecryptedVaultMapper {
  static DecryptedVault toEntity(DecryptedVaultModel model) => DecryptedVault(
    mnemonic: model.mnemonic,
    masterFingerprint: model.masterFingerprint,
    isEncryptedVaultTested: model.isEncryptedVaultTested,
    isPhysicalBackupTested: model.isPhysicalBackupTested,
    latestEncryptedBackup: model.latestEncryptedBackup,
    latestPhysicalBackup: model.latestPhysicalBackup,
  );
  static DecryptedVaultModel fromEntity(DecryptedVault vault) =>
      DecryptedVaultModel(
        mnemonic: vault.mnemonic,
        masterFingerprint: vault.masterFingerprint,
        isEncryptedVaultTested: vault.isEncryptedVaultTested,
        isPhysicalBackupTested: vault.isPhysicalBackupTested,
        latestEncryptedBackup: vault.latestEncryptedBackup,
        latestPhysicalBackup: vault.latestPhysicalBackup,
      );
}
