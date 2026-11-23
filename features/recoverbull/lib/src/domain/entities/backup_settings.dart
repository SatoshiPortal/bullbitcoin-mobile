import '../recoverbull_server_url.dart';

final class BackupSettings {
  final Uri server;
  final bool permissionGranted;
  final bool monitoringEnabled;
  final int generation;
  final bool serverEditable;

  BackupSettings({
    required Uri server,
    required this.permissionGranted,
    required this.monitoringEnabled,
    required this.generation,
    this.serverEditable = true,
  }) : server = validateRecoverBullServerUrl(server);
}

/// A successful legacy read. A failed read supplies no value and is retryable.
final class LegacyBackupSettings {
  final Uri server;
  final bool permissionGranted;

  LegacyBackupSettings({required Uri server, required this.permissionGranted})
    : server = validateRecoverBullServerUrl(server);
}
