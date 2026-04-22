/// Canonical drift schema version. Referenced from [SqliteDatabase] and
/// [MigrationReporter] so bumping the schema updates both the drift
/// migration strategy and the tag reported in migration Sentry events in
/// a single place.
///
/// Bump alongside any new `schema_N_to_N+1.dart` step and add the matching
/// `from{N}To{N+1}` entry in [SqliteDatabase.migration].
const int kDriftSchemaVersion = 12;
