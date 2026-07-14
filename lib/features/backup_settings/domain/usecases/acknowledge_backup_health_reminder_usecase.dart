import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_health_reminder_repository.dart';
import 'package:meta/meta.dart';

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
        highestHandledBalanceTier: BackupBalanceTier.highest(
          record.highestHandledBalanceTier,
          decision.currentBalanceTier,
        ),
        clearPendingAction: true,
      ),
    );
  }
}
