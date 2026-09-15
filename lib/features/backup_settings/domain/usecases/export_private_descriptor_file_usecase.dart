import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_test.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

/// Saves a vault's private descriptor backup as a file.
///
/// The file is the raw BIP138 artifact, the same bytes the server would hold,
/// so a cosigner with their own public key can recover from it offline and
/// nothing about the vault is readable without one.
final class ExportPrivateDescriptorFileUsecase {
  /// One extension for the artifact, named after the format rather than after
  /// this app, because any BIP138 reader can open it.
  static const fileExtension = 'bip138';

  final BullVaultFacade _vaults;
  final WalletBackupFileRepository _files;

  const ExportPrivateDescriptorFileUsecase(this._vaults, this._files);

  /// False when the person dismissed the save dialog.
  Future<Result<bool, BackupSettingsFailure>> execute(String walletId) async {
    final encoded = await _vaults.encodePrivateDescriptorBackup(walletId);
    if (encoded case Err()) {
      return const Err(BackupSettingsUnavailableFailure());
    }
    final backup =
        (encoded as Ok<BullVaultDescriptorBackup, BullVaultFailure>).value;
    final identity = VaultBackupTest.identity(
      backup.descriptor,
      backup.network.name,
    );
    return _files.save(
      WalletBackupExport(
        // The descriptor identity is a hash of public data, and it is what the
        // test receipts are already keyed by, so two vaults never collide.
        suggestedFilename:
            'bullvault-descriptor-${identity.substring(0, 8)}.$fileExtension',
        bytes: backup.bytes,
      ),
    );
  }
}
