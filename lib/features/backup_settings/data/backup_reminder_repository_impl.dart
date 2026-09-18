import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class BackupReminderRepositoryImpl implements BackupReminderRepository {
  static const _disabled = 'backup_reminders_dismiss_forever';
  static const _largeBalance = 'backup_reminders_large_balance_dismissed';
  static const _addPhysical = 'backup_reminders_add_physical_snooze_until';
  static const _physicalTest = 'backup_reminders_physical_test_snooze_until';
  static const _encryptedTest = 'backup_reminders_vault_test_snooze_until';

  @override
  Future<Result<BackupReminderPreferences, BackupSettingsFailure>>
  load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // A failed SharedPreferences write can still alter its in-memory cache.
      await prefs.reload();
      return Ok(
        BackupReminderPreferences(
          disabled: prefs.get(_disabled) == true,
          largeBalanceDismissed: prefs.get(_largeBalance) == true,
          addPhysicalUntil: _date(prefs.get(_addPhysical)),
          physicalTestUntil: _date(prefs.get(_physicalTest)),
          encryptedTestUntil: _date(prefs.get(_encryptedTest)),
        ),
      );
    } on Exception {
      return const Err(BackupSettingsUnexpectedFailure());
    }
  }

  @override
  Future<Result<void, BackupSettingsFailure>> setDisabled(bool disabled) =>
      _writeBool(_disabled, disabled);

  @override
  Future<Result<void, BackupSettingsFailure>> dismissLargeBalanceWarning() =>
      _writeBool(_largeBalance, true);

  @override
  Future<Result<void, BackupSettingsFailure>> snooze(
    BackupReminder reminder,
    DateTime until,
  ) async {
    final key = switch (reminder) {
      BackupReminder.addPhysicalBackup => _addPhysical,
      BackupReminder.testPhysicalBackup => _physicalTest,
      BackupReminder.testEncryptedVault => _encryptedTest,
      _ => throw ArgumentError.value(reminder, 'reminder'),
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setInt(key, until.millisecondsSinceEpoch)
          ? const Ok(null)
          : const Err(BackupSettingsUnexpectedFailure());
    } on Exception {
      return const Err(BackupSettingsUnexpectedFailure());
    }
  }

  Future<Result<void, BackupSettingsFailure>> _writeBool(
    String key,
    bool value,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(key, value)
          ? const Ok(null)
          : const Err(BackupSettingsUnexpectedFailure());
    } on Exception {
      return const Err(BackupSettingsUnexpectedFailure());
    }
  }

  static DateTime? _date(Object? value) =>
      value is int && value.abs() <= 8640000000000000
      ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)
      : null;
}
