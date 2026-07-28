import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_health_reminder_repository.dart';
import 'package:meta/meta.dart';

/// Snoozes a reminder for a full cycle.
///
/// This never writes a tested timestamp: the Backup Settings screen keeps
/// saying how long ago the backup was really tested while the popup is quiet.
class AcknowledgeBackupHealthReminderUsecase {
  final BackupHealthReminderRepository _repository;
  final DateTime Function() _clock;

  AcknowledgeBackupHealthReminderUsecase(
    this._repository, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  @useResult
  Future<Result<void, BackupSettingsFailure>> execute(
    BackupHealthDecision decision,
  ) async {
    final BackupHealthReminderRecord record;
    switch (await _repository.fetch(decision.masterFingerprint)) {
      case Ok(:final value):
        record = value;
      case Err(:final failure):
        return Err(failure);
    }

    return _repository.save(
      record.copyWith(
        lastAcknowledgedAt: _clock().toUtc(),
        crossedTenMillionSats:
            record.crossedTenMillionSats ||
            decision.trigger == BackupHealthTrigger.balanceMilestone,
      ),
    );
  }
}
