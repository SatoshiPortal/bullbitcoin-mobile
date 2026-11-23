import '../recoverbull_server_url.dart';

final class BackupSettings {
  final Uri server;
  final bool permissionGranted;
  final bool monitoringEnabled;
  final int generation;
  final int permissionRevision;
  final bool serverEditable;

  BackupSettings({
    required Uri server,
    required this.permissionGranted,
    required this.monitoringEnabled,
    required this.generation,
    this.permissionRevision = 0,
    this.serverEditable = true,
  }) : server = validateRecoverBullServerUrl(server);

  bool sameGeneration(BackupSettings other) =>
      generation == other.generation &&
      permissionRevision == other.permissionRevision;
}

/// A successful legacy read. A failed read supplies no value and is retryable.
final class LegacyBackupSettings {
  final Uri server;
  final bool permissionGranted;

  LegacyBackupSettings({required Uri server, required this.permissionGranted})
    : server = validateRecoverBullServerUrl(server);
}
