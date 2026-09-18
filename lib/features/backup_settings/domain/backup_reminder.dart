import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

enum BackupReminder {
  noTestedBackup,
  largeBalanceNeedsPhysicalBackup,
  addPhysicalBackup,
  testPhysicalBackup,
  testEncryptedVault;

  Duration? get snoozeInterval => switch (this) {
    addPhysicalBackup => const Duration(days: 180),
    testPhysicalBackup => const Duration(days: 365),
    testEncryptedVault => const Duration(days: 366),
    noTestedBackup || largeBalanceNeedsPhysicalBackup => null,
  };

  static BackupReminder? select(
    List<Wallet> wallets,
    BackupReminderPreferences preferences,
    DateTime now,
  ) {
    if (preferences.disabled) return null;
    final defaults = wallets.where(
      (wallet) => wallet.isDefault && wallet.network == Network.bitcoinMainnet,
    );
    if (defaults.length != 1) return null;

    final balance = wallets
        .where(
          (wallet) =>
              wallet.network.isMainnet &&
              wallet.hasLocalSigner &&
              !wallet.isHardwareWallet,
        )
        .fold(BigInt.zero, (total, wallet) => total + wallet.balanceSat);
    if (balance <= BigInt.zero) return null;

    final wallet = defaults.single;
    final physical = wallet.isPhysicalBackupTested
        ? wallet.latestPhysicalBackup
        : null;
    final encrypted = wallet.isEncryptedVaultTested
        ? wallet.latestEncryptedBackup
        : null;
    if (physical == null && encrypted == null) return noTestedBackup;

    if (physical == null && encrypted != null) {
      if (balance >= BigInt.from(10000000) &&
          !preferences.largeBalanceDismissed) {
        return largeBalanceNeedsPhysicalBackup;
      }
      if (addPhysicalBackup._isDue(encrypted, preferences, now)) {
        return addPhysicalBackup;
      }
    }
    if (physical != null &&
        testPhysicalBackup._isDue(physical, preferences, now)) {
      return testPhysicalBackup;
    }
    if (encrypted != null) {
      final reference = physical != null && physical.isAfter(encrypted)
          ? physical
          : encrypted;
      if (testEncryptedVault._isDue(reference, preferences, now)) {
        return testEncryptedVault;
      }
    }
    return null;
  }

  bool _isDue(
    DateTime reference,
    BackupReminderPreferences preferences,
    DateTime now,
  ) {
    final snoozedUntil = preferences.snoozedUntil(this);
    return !reference.add(snoozeInterval!).isAfter(now) &&
        (snoozedUntil == null || !snoozedUntil.isAfter(now));
  }
}

final class BackupReminderPreferences {
  final bool disabled;
  final bool largeBalanceDismissed;
  final DateTime? addPhysicalUntil;
  final DateTime? physicalTestUntil;
  final DateTime? encryptedTestUntil;

  const BackupReminderPreferences({
    this.disabled = false,
    this.largeBalanceDismissed = false,
    this.addPhysicalUntil,
    this.physicalTestUntil,
    this.encryptedTestUntil,
  });

  DateTime? snoozedUntil(BackupReminder reminder) => switch (reminder) {
    BackupReminder.addPhysicalBackup => addPhysicalUntil,
    BackupReminder.testPhysicalBackup => physicalTestUntil,
    BackupReminder.testEncryptedVault => encryptedTestUntil,
    BackupReminder.noTestedBackup ||
    BackupReminder.largeBalanceNeedsPhysicalBackup => null,
  };
}
