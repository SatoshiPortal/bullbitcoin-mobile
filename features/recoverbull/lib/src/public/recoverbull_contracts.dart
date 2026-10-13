import 'package:meta/meta.dart';
import '../domain/recoverbull_server_url.dart';
export '../database/recoverbull_lifecycle.dart' show RecoverBullLifecycle;
export '../domain/entities/recoverbull_server_settings.dart'
    show RecoverBullServerSettings;
export '../domain/entities/recoverbull_status.dart' show RecoverBullStatus;
export '../domain/entities/recoverbull_monitoring_status.dart'
    show RecoverBullMonitoringStatus;
export '../domain/recoverbull_server_url.dart'
    show validateRecoverBullServerUrl, recoverBullDefaultServerUrl;
export '../domain/recoverbull_timing.dart' show RecoverBullTiming;

export '../domain/entities/recoverbull_attempt_alert.dart';
export '../domain/recoverbull_attempt_monitoring_controller.dart';

@immutable
final class RecoverBullConfig {
  final String? databasePath;
  final Uri? defaultServer;
  final Uri? initialServerUrlOverride;
  final bool initialPermissionGranted;

  const RecoverBullConfig({
    required this.databasePath,
    this.defaultServer,
    this.initialServerUrlOverride,
    this.initialPermissionGranted = false,
  });

  Uri get effectiveDefaultServer =>
      defaultServer ?? Uri.parse(recoverBullDefaultServerUrl);
}

enum RecoverBullHealth { online, offline, timeout, temporarilyUnavailable }

/// The result of a recovery operation, excluding recovered secret material.
@immutable
final class RecoverBullRecoveryResult {
  final bool restored;

  const RecoverBullRecoveryResult({required this.restored});
}
