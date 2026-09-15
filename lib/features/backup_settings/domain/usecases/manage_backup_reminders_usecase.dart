import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';

final class LoadBackupReminderPreferencesUsecase {
  final BackupReminderRepository _repository;

  const LoadBackupReminderPreferencesUsecase(this._repository);

  Future<Result<BackupReminderPreferences, BackupSettingsFailure>> execute() =>
      _repository.load();
}

final class SelectBackupReminderUsecase {
  static const largeBalanceThresholdSats = 10000000;
  static const addPhysicalAfter = Duration(days: 180);
  static const testPhysicalAfter = Duration(days: 365);
  static const testEncryptedVaultAfter = Duration(days: 366);

  final BackupReminderRepository _repository;
  final DateTime Function() _now;

  SelectBackupReminderUsecase(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  Future<Result<BackupReminder?, BackupSettingsFailure>> execute(
    List<Wallet> wallets,
  ) async {
    final loaded = await _repository.load();
    switch (loaded) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.dismissForever) return const Ok(null);
        return Ok(_selectBackupReminder(wallets, value, _now()));
    }
  }
}

final class DismissBackupReminderUsecase {
  final BackupReminderRepository _repository;
  final DateTime Function() _now;

  DismissBackupReminderUsecase(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  Future<Result<void, BackupSettingsFailure>> execute(
    BackupReminder reminder,
  ) => switch (reminder) {
    BackupReminder.noTestedBackup => Future.value(const Ok(null)),
    BackupReminder.largeBalanceNeedsPhysicalBackup =>
      _repository.dismissLargeBalanceWarning(),
    BackupReminder.addPhysicalBackup => _repository.snooze(
      reminder,
      _now().add(addPhysicalAfter),
    ),
    BackupReminder.testPhysicalBackup => _repository.snooze(
      reminder,
      _now().add(testPhysicalAfter),
    ),
    BackupReminder.testEncryptedVault => _repository.snooze(
      reminder,
      _now().add(testEncryptedVaultAfter),
    ),
  };

  static const addPhysicalAfter = SelectBackupReminderUsecase.addPhysicalAfter;
  static const testPhysicalAfter =
      SelectBackupReminderUsecase.testPhysicalAfter;
  static const testEncryptedVaultAfter =
      SelectBackupReminderUsecase.testEncryptedVaultAfter;
}

final class SetBackupRemindersDismissedUsecase {
  final BackupReminderRepository _repository;

  const SetBackupRemindersDismissedUsecase(this._repository);

  Future<Result<void, BackupSettingsFailure>> execute(bool value) =>
      _repository.setDismissForever(value);
}

BackupReminder? _selectBackupReminder(
  List<Wallet> wallets,
  BackupReminderPreferences preferences,
  DateTime now,
) {
  final defaults = wallets
      .where(
        (wallet) =>
            wallet.isDefault &&
            wallet.network.isMainnet &&
            wallet.network.isBitcoin,
      )
      .toList();
  if (defaults.length != 1) return null;

  final defaultWallet = defaults.single;
  final physicalTest = defaultWallet.latestPhysicalBackup;
  final vaultTest = defaultWallet.latestEncryptedBackup;
  final eligibleBalance = wallets
      .where(
        (wallet) =>
            wallet.network.isMainnet &&
            wallet.signsLocally &&
            !wallet.isHardwareWallet,
      )
      .fold<BigInt>(BigInt.zero, (sum, wallet) => sum + wallet.balanceSat);
  if (eligibleBalance <= BigInt.zero) return null;

  if (physicalTest == null && vaultTest == null) {
    return BackupReminder.noTestedBackup;
  }

  if (physicalTest == null && vaultTest != null) {
    if (eligibleBalance >=
            BigInt.from(
              SelectBackupReminderUsecase.largeBalanceThresholdSats,
            ) &&
        !preferences.largeBalanceWarningDismissed) {
      return BackupReminder.largeBalanceNeedsPhysicalBackup;
    }
    if (_elapsed(
          vaultTest,
          SelectBackupReminderUsecase.addPhysicalAfter,
          now,
        ) &&
        _pastSnooze(preferences.addPhysicalSnoozedUntil, now)) {
      return BackupReminder.addPhysicalBackup;
    }
  }

  if (physicalTest != null &&
      _elapsed(
        physicalTest,
        SelectBackupReminderUsecase.testPhysicalAfter,
        now,
      ) &&
      _pastSnooze(preferences.physicalTestSnoozedUntil, now)) {
    return BackupReminder.testPhysicalBackup;
  }

  final vaultReminderBaseline = switch ((vaultTest, physicalTest)) {
    (final vault?, final physical?) when physical.isAfter(vault) => physical,
    (final vault?, _) => vault,
    _ => null,
  };
  if (vaultReminderBaseline != null &&
      _elapsed(
        vaultReminderBaseline,
        SelectBackupReminderUsecase.testEncryptedVaultAfter,
        now,
      ) &&
      _pastSnooze(preferences.encryptedVaultTestSnoozedUntil, now)) {
    return BackupReminder.testEncryptedVault;
  }

  return null;
}

bool _elapsed(DateTime test, Duration interval, DateTime now) =>
    !test.add(interval).isAfter(now);

bool _pastSnooze(DateTime? snoozedUntil, DateTime now) =>
    snoozedUntil == null || !snoozedUntil.isAfter(now);
