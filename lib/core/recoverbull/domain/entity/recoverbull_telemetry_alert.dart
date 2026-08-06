/// Advisory brute-force telemetry alerts, surfaced to the user as warnings.
///
/// Trust model (binding for all UI copy): the key server cannot distinguish
/// an attacker from the user or another of the user's devices, and a
/// compromised server can fabricate or suppress counters. Every alert is
/// advisory — the UI warns, never acts automatically.
///
/// Pure Dart, no Flutter and no SDK types.
sealed class RecoverbullTelemetryAlert {
  const RecoverbullTelemetryAlert();
}

/// Strong warning: the snapshot or `attempt_status` shows attempts the user
/// did not make on this backup. [observedTotal] vs [expectedTotal] (this
/// device's own operations) drives the copy.
final class SuspiciousActivityAlert extends RecoverbullTelemetryAlert {
  final String backupIdHash;
  final int observedTotal;
  final int expectedTotal;
  final DateTime windowStartedAt;

  const SuspiciousActivityAlert({
    required this.backupIdHash,
    required this.observedTotal,
    required this.expectedTotal,
    required this.windowStartedAt,
  });
}

/// Strong warning: the user's own fetch hit the targeted per-identifier
/// lockout (HTTP 429). Someone may be probing or griefing this backup.
final class TargetedLockoutAlert extends RecoverbullTelemetryAlert {
  final String backupIdHash;

  const TargetedLockoutAlert({required this.backupIdHash});
}

/// The kind of service-wide pressure the key server reports. Never an
/// attack signal.
enum ServicePressureKind { global429, capacity503, mapNearlyFull }

/// Service pressure notice: the key server is overloaded or its rate-limit
/// map is nearly full. Shown inline, never as a modal.
final class ServicePressureAlert extends RecoverbullTelemetryAlert {
  final ServicePressureKind kind;

  const ServicePressureAlert(this.kind);
}

/// Soft warning: `/attempts` has been unreachable. Flooding the route is the
/// realistic way to suppress telemetry during an attack, so a prolonged
/// outage is itself surfaced — softly.
///
/// [since] is null when monitoring never succeeded yet (feature just enabled,
/// Tor still settling): there is no duration to report, and the copy must not
/// fabricate one.
final class TelemetryUnavailableAlert extends RecoverbullTelemetryAlert {
  final Duration? since;

  const TelemetryUnavailableAlert({required this.since});
}

/// Neutral notice: the server restarted and wiped its in-memory counters at
/// [wipedAt] (`attempts_collection_started_at` changed). The baseline was
/// reset; this is **not** an attack alarm.
final class CountersWipedAlert extends RecoverbullTelemetryAlert {
  final DateTime wipedAt;

  const CountersWipedAlert({required this.wipedAt});
}
