import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:meta/meta.dart';

abstract interface class BackupHealthReminderRepository {
  @useResult
  Future<Result<BackupHealthReminderRecord, BackupSettingsFailure>> fetch(
    String masterFingerprint,
  );

  @useResult
  Future<Result<void, BackupSettingsFailure>> save(
    BackupHealthReminderRecord record,
  );
}
