import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';

abstract interface class BackupReminderRepository {
  Future<Result<BackupReminderPreferences, BackupSettingsFailure>> load();
  Future<Result<void, BackupSettingsFailure>> setDisabled(bool disabled);
  Future<Result<void, BackupSettingsFailure>> dismissLargeBalanceWarning();
  Future<Result<void, BackupSettingsFailure>> snooze(
    BackupReminder reminder,
    DateTime until,
  );
}
