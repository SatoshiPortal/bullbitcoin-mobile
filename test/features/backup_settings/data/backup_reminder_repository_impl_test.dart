import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/data/backup_reminder_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists only the five reminder decisions', () async {
    final repository = BackupReminderRepositoryImpl();
    final now = DateTime.utc(2026, 8, 28);

    await repository.setDismissForever(true);
    await repository.dismissLargeBalanceWarning();
    await repository.snooze(BackupReminder.addPhysicalBackup, now);
    await repository.snooze(
      BackupReminder.testPhysicalBackup,
      now.add(const Duration(days: 1)),
    );
    await repository.snooze(
      BackupReminder.testEncryptedVault,
      now.add(const Duration(days: 2)),
    );

    final loaded = await repository.load();
    final preferences = switch (loaded) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError(failure.runtimeType.toString()),
    };
    expect(preferences.dismissForever, isTrue);
    expect(preferences.largeBalanceWarningDismissed, isTrue);
    expect(preferences.addPhysicalSnoozedUntil, now);
    expect(
      preferences.physicalTestSnoozedUntil,
      now.add(const Duration(days: 1)),
    );
    expect(
      preferences.encryptedVaultTestSnoozedUntil,
      now.add(const Duration(days: 2)),
    );
    expect((await SharedPreferences.getInstance()).getKeys(), hasLength(5));
  });

  test('invalid stored types fall back to unsuppressed reminders', () async {
    SharedPreferences.setMockInitialValues({
      'backup_reminders_dismiss_forever': 'invalid',
      'backup_reminders_large_balance_dismissed': 1,
      'backup_reminders_add_physical_snooze_until': false,
    });
    final loaded = await BackupReminderRepositoryImpl().load();
    final preferences = switch (loaded) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError(failure.runtimeType.toString()),
    };

    expect(preferences.dismissForever, isFalse);
    expect(preferences.largeBalanceWarningDismissed, isFalse);
    expect(preferences.addPhysicalSnoozedUntil, isNull);
  });
}
