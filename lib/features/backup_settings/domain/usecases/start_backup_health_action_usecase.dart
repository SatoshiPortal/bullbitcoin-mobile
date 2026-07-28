import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_health_reminder_repository.dart';
import 'package:meta/meta.dart';

/// Records that the user has been told about the balance milestone, at the
/// moment they act on it.
///
/// The milestone popup is a one-time notice, so acting on it retires the notice
/// whether or not the flow is finished. The schedule is deliberately untouched:
/// completing the action updates the real tested timestamp, and abandoning it
/// leaves a due reminder due.
class StartBackupHealthActionUsecase {
  final BackupHealthReminderRepository _repository;

  StartBackupHealthActionUsecase(this._repository);

  @useResult
  Future<Result<void, BackupSettingsFailure>> execute(
    BackupHealthDecision decision,
  ) async {
    if (decision.trigger != BackupHealthTrigger.balanceMilestone) {
      return const Ok(null);
    }

    final BackupHealthReminderRecord record;
    switch (await _repository.fetch(decision.masterFingerprint)) {
      case Ok(:final value):
        record = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (record.crossedTenMillionSats) return const Ok(null);

    return _repository.save(record.copyWith(crossedTenMillionSats: true));
  }
}
