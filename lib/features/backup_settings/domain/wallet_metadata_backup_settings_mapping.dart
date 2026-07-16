import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/entities/backup_settings_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/public/wallet_metadata_backup_facade.dart';

WalletMetadataBackupSettingsSnapshot mapWalletMetadataBackupSettings(
  WalletMetadataBackupState state,
) {
  return WalletMetadataBackupSettingsSnapshot(
    enabled: state.enabled,
    dirty: state.dirty,
    blocked:
        state.unsupportedNewerEnvelope != null || state.recoveryBlock != null,
    hasRemoteBackup: state.verifiedHead != null,
    lastVerifiedAt: state.lastSucceededAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            state.lastSucceededAt! * 1000,
            isUtc: true,
          ),
  );
}

BackupSettingsFailure mapWalletMetadataBackupFailure(
  WalletMetadataBackupFailure failure,
) {
  return BackupSettingsUnexpectedFailure(
    'Wallet metadata backup failed: ${failure.runtimeType}',
  );
}
