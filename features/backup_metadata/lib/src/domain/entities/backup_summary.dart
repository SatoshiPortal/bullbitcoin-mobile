/// What the journal says without touching any storage.
final class BackupSummary {
  /// A destination and at least one group are selected in the active view.
  final bool enabled;
  final DateTime? lastDurableBackup;

  const BackupSummary({required this.enabled, this.lastDurableBackup});

  static const off = BackupSummary(enabled: false);
}
