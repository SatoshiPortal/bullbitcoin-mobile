sealed class AttemptAlert {
  const AttemptAlert();
}

final class SuspiciousActivityAlert extends AttemptAlert {
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

final class TargetedLockoutAlert extends AttemptAlert {
  final String backupIdHash;
  const TargetedLockoutAlert({required this.backupIdHash});
}

enum ServicePressureKind { serviceBusy, identifierSaturation }

final class ServicePressureAlert extends AttemptAlert {
  final ServicePressureKind kind;
  const ServicePressureAlert(this.kind);
}

final class AttemptMonitoringUnavailableAlert extends AttemptAlert {
  final Duration? since;
  const AttemptMonitoringUnavailableAlert({required this.since});
}
