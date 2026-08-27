import 'package:drift/drift.dart';

/// The telemetry baseline for one monitored backup (one row per backup per
/// key-server URL).
///
/// `backupIdHash` is `sha256(raw backup id)` — the same value the server
/// publishes. The raw backup id never enters this table; the baseline still
/// reveals which backups are monitored to someone with device access, so it
/// lives in the same protected store as other sensitive app state.
@DataClassName('RecoverbullTelemetryBackupRow')
class RecoverbullTelemetryBackup extends Table {
  TextColumn get serverUrl => text()();
  TextColumn get backupIdHash => text()();

  /// The server's distinct-candidate total as of this device's last own
  /// operation in the current window — what we expect to still see if nothing
  /// foreign happened. Not a local operation counter: the server counts
  /// distinct authentication candidates, so a replayed password adds nothing.
  /// Another device sharing the backup produces a conservative false positive
  /// — handled by copy ("was it you or another device?") plus acknowledgement
  /// memory.
  IntColumn get expectedTotalAttempts =>
      integer().withDefault(const Constant(0))();

  /// Epoch seconds of the window [expectedTotalAttempts] belongs to. The
  /// server's window rolls over after the cooldown; a mismatch means the
  /// local counter is stale and must reset before any comparison.
  IntColumn get currentWindowStartedAt => integer().nullable()();

  /// Epoch seconds of the window start of the last warning shown for this
  /// backup (dedup per attempt window).
  IntColumn get lastWarningWindowStartedAt => integer().nullable()();

  /// Epoch seconds of the last user acknowledgement (multi-device false
  /// positives must not train the user to ignore alerts).
  IntColumn get acknowledgedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {serverUrl, backupIdHash};
}
