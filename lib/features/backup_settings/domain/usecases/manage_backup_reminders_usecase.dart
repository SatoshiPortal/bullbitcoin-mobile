import 'package:bb_mobile/core/utils/result.dart';
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

  const SelectBackupReminderUsecase(this._repository);

  Future<
    Result<
      ({BackupReminderPreferences preferences, BackupReminder? reminder}),
      BackupSettingsFailure
    >
  >
  execute(List<Wallet> wallets, {DateTime? now}) async =>
      switch (await _repository.load()) {
        Ok(:final value) => Ok((
          preferences: value,
          reminder: BackupReminder.select(
            wallets,
            value,
            now ?? DateTime.now(),
          ),
        )),
        Err(:final failure) => Err(failure),
      };
}

final class DismissBackupReminderUsecase {
  final BackupReminderRepository _repository;

  const DismissBackupReminderUsecase(this._repository);

  Future<Result<void, BackupSettingsFailure>> execute(
    BackupReminder reminder, {
    DateTime? now,
  }) => switch (reminder) {
    BackupReminder.noTestedBackup => Future.value(const Ok(null)),
    BackupReminder.largeBalanceNeedsPhysicalBackup =>
      _repository.dismissLargeBalanceWarning(),
    _ => _repository.snooze(
      reminder,
      (now ?? DateTime.now()).add(reminder.snoozeInterval!),
    ),
  };
}

final class SetBackupRemindersDisabledUsecase {
  final BackupReminderRepository _repository;

  const SetBackupRemindersDisabledUsecase(this._repository);

  Future<Result<void, BackupSettingsFailure>> execute(bool disabled) =>
      _repository.setDisabled(disabled);
}
