import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class BackupReminderRepositoryImpl implements BackupReminderRepository {
  static const _dismissForeverKey = 'backup_reminders_dismiss_forever';
  static const _largeBalanceDismissedKey =
      'backup_reminders_large_balance_dismissed';
  static const _addPhysicalSnoozeKey =
      'backup_reminders_add_physical_snooze_until';
  static const _physicalTestSnoozeKey =
      'backup_reminders_physical_test_snooze_until';
  static const _vaultTestSnoozeKey = 'backup_reminders_vault_test_snooze_until';

  @override
  Future<Result<BackupReminderPreferences, BackupSettingsFailure>>
  load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Ok(
        BackupReminderPreferences(
          dismissForever: _bool(prefs, _dismissForeverKey),
          largeBalanceWarningDismissed: _bool(prefs, _largeBalanceDismissedKey),
          addPhysicalSnoozedUntil: _date(prefs, _addPhysicalSnoozeKey),
          physicalTestSnoozedUntil: _date(prefs, _physicalTestSnoozeKey),
          encryptedVaultTestSnoozedUntil: _date(prefs, _vaultTestSnoozeKey),
        ),
      );
    } on Exception catch (error, trace) {
      return _failure('read', error, trace);
    }
  }

  @override
  Future<Result<void, BackupSettingsFailure>> setDismissForever(bool value) =>
      _writeBool(_dismissForeverKey, value);

  @override
  Future<Result<void, BackupSettingsFailure>> dismissLargeBalanceWarning() =>
      _writeBool(_largeBalanceDismissedKey, true);

  @override
  Future<Result<void, BackupSettingsFailure>> snooze(
    BackupReminder reminder,
    DateTime until,
  ) {
    final key = switch (reminder) {
      BackupReminder.addPhysicalBackup => _addPhysicalSnoozeKey,
      BackupReminder.testPhysicalBackup => _physicalTestSnoozeKey,
      BackupReminder.testEncryptedVault => _vaultTestSnoozeKey,
      _ => throw ArgumentError.value(reminder, 'reminder', 'Cannot be snoozed'),
    };
    return _writeInt(key, until.millisecondsSinceEpoch);
  }

  Future<Result<void, BackupSettingsFailure>> _writeBool(
    String key,
    bool value,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(key, value)) {
        return const Err(BackupSettingsUnexpectedFailure());
      }
      return const Ok(null);
    } on Exception catch (error, trace) {
      return _failure('write', error, trace);
    }
  }

  Future<Result<void, BackupSettingsFailure>> _writeInt(
    String key,
    int value,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setInt(key, value)) {
        return const Err(BackupSettingsUnexpectedFailure());
      }
      return const Ok(null);
    } on Exception catch (error, trace) {
      return _failure('write', error, trace);
    }
  }

  static DateTime? _date(SharedPreferences prefs, String key) {
    final milliseconds = prefs.get(key);
    return milliseconds is int
        ? DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true)
        : null;
  }

  static bool _bool(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    return value is bool ? value : false;
  }

  static Err<T, BackupSettingsFailure> _failure<T>(
    String operation,
    Exception error,
    StackTrace trace,
  ) {
    log.warning(
      'Could not $operation backup reminder preferences',
      error: error.runtimeType,
      trace: trace,
    );
    return const Err(BackupSettingsUnexpectedFailure());
  }
}
