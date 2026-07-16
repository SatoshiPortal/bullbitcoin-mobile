final class GetPaidSettings {
  final bool automatedBackupEnabled;
  final bool backupPending;
  final int? lastBackedUpAt;
  final int? unsupportedVersion;

  const GetPaidSettings({
    required this.automatedBackupEnabled,
    required this.backupPending,
    required this.lastBackedUpAt,
    required this.unsupportedVersion,
  });
}
