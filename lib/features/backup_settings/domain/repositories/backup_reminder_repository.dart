import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:meta/meta.dart';

abstract interface class BackupReminderRepository {
  @useResult
  Future<Result<BackupReminderPreferences, BackupSettingsFailure>> load();

  @useResult
  Future<Result<void, BackupSettingsFailure>> setDismissForever(bool value);

  @useResult
  Future<Result<void, BackupSettingsFailure>> dismissLargeBalanceWarning();

  @useResult
  Future<Result<void, BackupSettingsFailure>> snooze(
    BackupReminder reminder,
    DateTime until,
  );
}
