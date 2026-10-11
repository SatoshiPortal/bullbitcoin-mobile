import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

sealed class BackupSettingsFailure extends Failure {
  const BackupSettingsFailure([super.logMessage]);

  static BackupSettingsFailure fromDataBackup(WalletBackupFailure failure) =>
      switch (failure) {
        WalletBackupNetworkFailure() => const BackupSettingsNetworkFailure(),
        WalletBackupTimeoutFailure() => const BackupSettingsTimeoutFailure(),
        WalletBackupMissingFailure() =>
          const BackupSettingsDataMissingFailure(),
        WalletBackupCredentialFailure() =>
          const BackupSettingsWordsUnavailableFailure(),
        WalletBackupIncompleteFailure() =>
          const BackupSettingsRecoveryIncompleteFailure(),
        WalletBackupRateLimitedFailure(:final retryAt) =>
          BackupSettingsRateLimitedFailure(retryAt),
        WalletBackupChangedFailure() => const BackupSettingsChangedFailure(),
        WalletBackupInvalidFailure() => const BackupSettingsInvalidFailure(),
        WalletBackupUnsupportedFailure() =>
          const BackupSettingsUnsupportedFailure(),
        WalletBackupTooLargeFailure() => const BackupSettingsTooLargeFailure(),
        WalletBackupConflictFailure() => const BackupSettingsConflictFailure(),
        WalletBackupConfirmationRequiredFailure() =>
          const BackupSettingsConfirmationRequiredFailure(),
        WalletBackupDeleteRequiresDisabledFailure() =>
          const BackupSettingsDeleteRequiresDisabledFailure(),
        WalletBackupStorageFailure() => const BackupSettingsUnexpectedFailure(),
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

final class BackupSettingsTimeoutFailure extends BackupSettingsFailure {
  const BackupSettingsTimeoutFailure();
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

final class BackupSettingsChangedFailure extends BackupSettingsFailure {
  const BackupSettingsChangedFailure();
}

final class BackupSettingsInvalidFailure extends BackupSettingsFailure {
  const BackupSettingsInvalidFailure();
}

final class BackupSettingsUnsupportedFailure extends BackupSettingsFailure {
  const BackupSettingsUnsupportedFailure();
}

final class BackupSettingsTooLargeFailure extends BackupSettingsFailure {
  const BackupSettingsTooLargeFailure();
}

final class BackupSettingsConflictFailure extends BackupSettingsFailure {
  const BackupSettingsConflictFailure();
}

final class BackupSettingsConfirmationRequiredFailure
    extends BackupSettingsFailure {
  const BackupSettingsConfirmationRequiredFailure();
}

final class BackupSettingsDeleteRequiresDisabledFailure
    extends BackupSettingsFailure {
  const BackupSettingsDeleteRequiresDisabledFailure();
}
