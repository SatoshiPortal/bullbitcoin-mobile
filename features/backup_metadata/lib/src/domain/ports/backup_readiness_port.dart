/// Implemented at the composition root: a background run touches nothing
/// until the foreground app has migrated the database.
abstract interface class BackupReadinessPort {
  Future<bool> databaseReady();
}
