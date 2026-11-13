import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';

final class LoadBackupReminderPreferencesUsecase {
  final BackupReminderRepository _repository;

  const LoadBackupReminderPreferencesUsecase(this._repository);

  Future<Result<BackupReminderPreferences, BackupSettingsFailure>> execute() =>
      _repository.load();
}

final class SelectBackupReminderUsecase {
  final BackupReminderRepository _repository;

  final Future<Result<rb.BackupStatus, rb.RecoverBullFailure>> Function(
    rb.VaultContext,
  )
  _backupStatus;
  const SelectBackupReminderUsecase(this._repository, this._backupStatus);

  Future<
    Result<
      ({BackupReminderPreferences preferences, BackupReminder? reminder}),
      BackupSettingsFailure
    >
  >
  execute(List<Wallet> wallets, {DateTime? now}) async {
    final BackupReminderPreferences preferences;
    switch (await _repository.load()) {
      case Ok(:final value):
        preferences = value;
      case Err(:final failure):
        return Err(failure);
    }
    final defaults = wallets.where(
      (wallet) => wallet.isDefault && wallet.network == Network.bitcoinMainnet,
    );
    if (preferences.disabled || defaults.length != 1) {
      return Ok((preferences: preferences, reminder: null));
    }
    final fingerprint = rb.Fingerprint.tryParse(
      defaults.single.masterFingerprint,
    );
    if (fingerprint == null) {
      return const Err(BackupSettingsUnexpectedFailure());
    }
    final status = await _backupStatus(
      rb.VaultContext(
        fingerprint: fingerprint,
        network: rb.BitcoinNetwork.mainnet,
      ),
    );
    return switch (status) {
      Ok(:final value) => Ok((
        preferences: preferences,
        reminder: BackupReminder.select(
          wallets,
          preferences,
          now ?? DateTime.now(),
          encryptedVerifiedAt: value.verifiedAt,
        ),
      )),
      Err() => const Err(BackupSettingsUnexpectedFailure()),
    };
  }
}

final class DismissBackupReminderUsecase {
  final BackupReminderRepository _repository;

  const DismissBackupReminderUsecase(this._repository);

  Future<Result<void, BackupSettingsFailure>> execute(
    BackupReminder reminder, {
    DateTime? now,
  }) => switch (reminder.snoozeInterval) {
    null => _repository.dismissLargeBalanceWarning(),
    final interval => _repository.snooze(
      reminder,
      (now ?? DateTime.now()).add(interval),
    ),
  };
}

final class SetBackupRemindersDisabledUsecase {
  final BackupReminderRepository _repository;

  const SetBackupRemindersDisabledUsecase(this._repository);

  Future<Result<void, BackupSettingsFailure>> execute(bool disabled) =>
      _repository.setDisabled(disabled);
}
