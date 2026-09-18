import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/data/backup_reminder_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'global disabling and re-enabling survive repository recreation',
    () async {
      final repository = BackupReminderRepositoryImpl();
      expect(
        await repository.setDisabled(true),
        isA<Ok<void, BackupSettingsFailure>>(),
      );
      var loaded = await BackupReminderRepositoryImpl().load();
      expect(
        (loaded as Ok<BackupReminderPreferences, BackupSettingsFailure>)
            .value
            .disabled,
        isTrue,
      );
      await repository.setDisabled(false);
      loaded = await BackupReminderRepositoryImpl().load();
      expect(
        (loaded as Ok<BackupReminderPreferences, BackupSettingsFailure>)
            .value
            .disabled,
        isFalse,
      );
    },
  );

  test('snoozing one reminder preserves the other reminder choices', () async {
    final repository = BackupReminderRepositoryImpl();
    final until = DateTime.utc(2027, 3, 17);
    await repository.dismissLargeBalanceWarning();
    await repository.snooze(BackupReminder.addPhysicalBackup, until);
    await repository.setDisabled(true);
    await repository.setDisabled(false);
    final loaded = await BackupReminderRepositoryImpl().load();
    final preferences =
        (loaded as Ok<BackupReminderPreferences, BackupSettingsFailure>).value;
    expect(preferences.largeBalanceDismissed, isTrue);
    expect(preferences.addPhysicalUntil, until);
    expect(preferences.physicalTestUntil, isNull);
    expect(preferences.encryptedTestUntil, isNull);
    expect(preferences.disabled, isFalse);
  });

  test(
    'reads retained preference keys without migrating unrelated state',
    () async {
      final until = DateTime.utc(2027, 9, 18);
      SharedPreferences.setMockInitialValues({
        'backup_reminders_dismiss_forever': true,
        'backup_reminders_large_balance_dismissed': true,
        'backup_reminders_vault_test_snooze_until':
            until.millisecondsSinceEpoch,
        'unrelated_setting': 'preserve',
      });
      final loaded = await BackupReminderRepositoryImpl().load();
      final preferences =
          (loaded as Ok<BackupReminderPreferences, BackupSettingsFailure>)
              .value;
      expect(preferences.disabled, isTrue);
      expect(preferences.largeBalanceDismissed, isTrue);
      expect(preferences.encryptedTestUntil, until);
      await BackupReminderRepositoryImpl().setDisabled(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('unrelated_setting'), 'preserve');
    },
  );
}
