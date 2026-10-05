import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dismissal saves the reminder interval or one-time choice', () async {
    final now = DateTime.utc(2026, 9, 18);
    final repository = _Repository();
    final dismiss = DismissBackupReminderUsecase(repository);
    for (final entry in {
      BackupReminder.addPhysicalBackup: 180,
      BackupReminder.testPhysicalBackup: 365,
      BackupReminder.testEncryptedVault: 366,
    }.entries) {
      expect(
        await dismiss.execute(entry.key, now: now),
        isA<Ok<void, BackupSettingsFailure>>(),
      );
      expect(repository.lastSnooze, (
        entry.key,
        now.add(Duration(days: entry.value)),
      ));
    }
    expect(
      await dismiss.execute(BackupReminder.largeBalanceNeedsPhysicalBackup),
      isA<Ok<void, BackupSettingsFailure>>(),
    );
    expect(repository.largeBalanceDismissed, isTrue);
  });
}

class _Repository extends Fake implements BackupReminderRepository {
  (BackupReminder, DateTime)? lastSnooze;
  bool largeBalanceDismissed = false;

  @override
  Future<Result<void, BackupSettingsFailure>> snooze(
    BackupReminder reminder,
    DateTime until,
  ) async {
    lastSnooze = (reminder, until);
    return const Ok(null);
  }

  @override
  Future<Result<void, BackupSettingsFailure>>
  dismissLargeBalanceWarning() async {
    largeBalanceDismissed = true;
    return const Ok(null);
  }
}
