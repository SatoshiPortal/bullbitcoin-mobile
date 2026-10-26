/// How a backup entered attempt monitoring.
enum MonitoredBackupOrigin {
  /// Created on this device.
  created,

  /// Adopted after a recovery or a key-server attempt on this device.
  adopted,

  /// Discovered in the connected Google Drive account.
  drive,
}

/// A backup whose key-server attempt counter is watched for activity this
/// device did not cause. Only the digest of the backup identifier is kept.
final class MonitoredBackup {
  static const digestLength = 32;

  final List<int> digest;
  final int expectedServerDistinctCandidateTotal;
  final int currentWindow;
  final int? lastWarningWindow;
  final int rowRevision;
  final MonitoredBackupOrigin origin;

  /// SHA-256 (hex) of the Google account e-mail, never the address itself.
  final String? driveAccountHash;
  final String? driveFileId;
  final DateTime? driveFileCreatedAt;
  final DateTime? driveFileModifiedAt;

  MonitoredBackup({
    required List<int> digest,
    required this.expectedServerDistinctCandidateTotal,
    required this.currentWindow,
    required this.lastWarningWindow,
    required this.rowRevision,
    required this.origin,
    this.driveAccountHash,
    this.driveFileId,
    this.driveFileCreatedAt,
    this.driveFileModifiedAt,
  }) : digest = List<int>.unmodifiable(digest) {
    if (digest.length != digestLength) {
      throw ArgumentError.value(digest.length, 'digest', 'must be 32 bytes');
    }
    if (expectedServerDistinctCandidateTotal < 0) {
      throw ArgumentError.value(
        expectedServerDistinctCandidateTotal,
        'expectedServerDistinctCandidateTotal',
      );
    }
    if (currentWindow < 0) {
      throw ArgumentError.value(currentWindow, 'currentWindow');
    }
    if (lastWarningWindow != null && lastWarningWindow! < 0) {
      throw ArgumentError.value(lastWarningWindow, 'lastWarningWindow');
    }
    if (rowRevision < 0) throw ArgumentError.value(rowRevision, 'rowRevision');
  }

  /// A row registered without a baseline: no counter has been observed yet.
  bool get awaitsBaseline => currentWindow == 0 && lastWarningWindow == 0;
}
