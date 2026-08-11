import 'package:drift/drift.dart';

/// Snapshot polling state for one key-server URL (one row per server).
///
/// Scoped per server URL: changing the key-server URL invalidates ETag,
/// baselines and `collectionStartedAt` — identifiers and snapshots from
/// different servers are unrelated.
@DataClassName('RecoverbullTelemetryServerRow')
class RecoverbullTelemetryServer extends Table {
  TextColumn get serverUrl => text()();

  /// The last ETag served by `/attempts`, sent back as `If-None-Match`.
  TextColumn get lastEtag => text().nullable()();

  /// Epoch seconds of the last successful `/attempts` poll.
  IntColumn get lastSuccessfulCheckAt => integer().nullable()();

  /// Epoch seconds of the server's `attempts_collection_started_at` (from
  /// `/info`). A change means the server wiped its counters: reset the
  /// baseline without raising an attack alarm.
  IntColumn get collectionStartedAt => integer().nullable()();

  /// Consecutive failed `/attempts` polls, driving the prolonged-
  /// unavailability soft warning.
  IntColumn get consecutiveFailures =>
      integer().withDefault(const Constant(0))();

  /// Epoch seconds of the last prolonged-unavailability warning (dedup).
  IntColumn get unavailabilityWarnedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {serverUrl};
}
