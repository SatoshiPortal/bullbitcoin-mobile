import 'package:meta/meta.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';

abstract interface class BackupReminderRepository {
  @useResult
  Future<Result<BackupReminderPreferences, BackupSettingsFailure>> load();
  @useResult
  Future<Result<void, BackupSettingsFailure>> setDisabled(bool disabled);
  @useResult
  Future<Result<void, BackupSettingsFailure>> dismissLargeBalanceWarning();
  @useResult
  Future<Result<void, BackupSettingsFailure>> snooze(
    BackupReminder reminder,
    DateTime until,
  );
}
