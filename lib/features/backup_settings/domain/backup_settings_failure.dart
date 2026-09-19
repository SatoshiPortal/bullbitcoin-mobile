import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

sealed class BackupSettingsFailure extends Failure {
  const BackupSettingsFailure([super.logMessage]);

  static BackupSettingsFailure fromDataBackup(WalletBackupFailure failure) =>
      switch (failure) {
        WalletBackupNetworkFailure() => const BackupSettingsNetworkFailure(),
        WalletBackupMissingFailure() =>
          const BackupSettingsDataMissingFailure(),
        WalletBackupCredentialFailure() =>
          const BackupSettingsWordsUnavailableFailure(),
        WalletBackupIncompleteFailure() =>
          const BackupSettingsRecoveryIncompleteFailure(),
        WalletBackupRateLimitedFailure(:final retryAt) =>
          BackupSettingsRateLimitedFailure(retryAt),
        WalletBackupStorageFailure() ||
        WalletBackupChangedFailure() ||
        WalletBackupInvalidFailure() ||
        WalletBackupUnsupportedFailure() ||
        WalletBackupTooLargeFailure() ||
        WalletBackupConflictFailure() ||
        WalletBackupConfirmationRequiredFailure() ||
        WalletBackupDeleteRequiresDisabledFailure() =>
          const BackupSettingsUnexpectedFailure(),
      };
}

final class BackupSettingsUnexpectedFailure extends BackupSettingsFailure {
  const BackupSettingsUnexpectedFailure([super.logMessage]);
}

final class BackupSettingsVaultMismatchFailure extends BackupSettingsFailure {
  const BackupSettingsVaultMismatchFailure();
}

final class BackupSettingsNetworkFailure extends BackupSettingsFailure {
  const BackupSettingsNetworkFailure();
}

final class BackupSettingsDataMissingFailure extends BackupSettingsFailure {
  const BackupSettingsDataMissingFailure();
}

final class BackupSettingsRecoveryIncompleteFailure
    extends BackupSettingsFailure {
  const BackupSettingsRecoveryIncompleteFailure();
}

final class BackupSettingsRateLimitedFailure extends BackupSettingsFailure {
  final DateTime retryAt;
  const BackupSettingsRateLimitedFailure(this.retryAt);
}

final class BackupSettingsWordsUnavailableFailure
    extends BackupSettingsFailure {
  const BackupSettingsWordsUnavailableFailure();
}
