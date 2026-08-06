import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_telemetry_alert.dart';

/// The advisory telemetry alerts currently surfaced to the user.
class RecoverbullTelemetryState {
  final List<RecoverbullTelemetryAlert> alerts;

  const RecoverbullTelemetryState({this.alerts = const []});

  RecoverbullTelemetryState copyWith({
    List<RecoverbullTelemetryAlert>? alerts,
  }) {
    return RecoverbullTelemetryState(alerts: alerts ?? this.alerts);
  }

  /// Strong warnings shown as a modal on cold launch plus a persistent
  /// banner until acknowledged.
  List<RecoverbullTelemetryAlert> get strongWarnings => alerts
      .where((a) => a is SuspiciousActivityAlert || a is TargetedLockoutAlert)
      .toList();

  /// Service pressure notices, shown inline only (never a modal).
  List<ServicePressureAlert> get servicePressures =>
      alerts.whereType<ServicePressureAlert>().toList();

  /// Soft warnings (unavailability, counters wiped), banner only.
  List<RecoverbullTelemetryAlert> get softWarnings => alerts
      .where((a) => a is TelemetryUnavailableAlert || a is CountersWipedAlert)
      .toList();
}
