enum BackupReminder {
  noTestedBackup,
  largeBalanceNeedsPhysicalBackup,
  addPhysicalBackup,
  testPhysicalBackup,
  testEncryptedVault,
}

final class BackupReminderPreferences {
  final bool dismissForever;
  final bool largeBalanceWarningDismissed;
  final DateTime? addPhysicalSnoozedUntil;
  final DateTime? physicalTestSnoozedUntil;
  final DateTime? encryptedVaultTestSnoozedUntil;

  const BackupReminderPreferences({
    this.dismissForever = false,
    this.largeBalanceWarningDismissed = false,
    this.addPhysicalSnoozedUntil,
    this.physicalTestSnoozedUntil,
    this.encryptedVaultTestSnoozedUntil,
  });
}
