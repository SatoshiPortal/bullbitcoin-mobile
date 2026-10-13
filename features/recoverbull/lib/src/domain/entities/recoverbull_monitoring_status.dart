import 'package:meta/meta.dart';

@immutable
final class RecoverBullMonitoringStatus {
  final bool enabled;
  final bool serverUnsupported;
  final int monitoredCount;
  final DateTime? lastSuccessfulCheck;

  const RecoverBullMonitoringStatus({
    required this.enabled,
    this.serverUnsupported = false,
    required this.monitoredCount,
    required this.lastSuccessfulCheck,
  });

  bool get isUncovered => monitoredCount == 0;
}
