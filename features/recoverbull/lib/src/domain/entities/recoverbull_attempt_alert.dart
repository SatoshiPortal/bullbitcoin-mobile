sealed class RecoverbullAttemptAlert {
  const RecoverbullAttemptAlert();
}

final class SuspiciousActivityAlert extends RecoverbullAttemptAlert {
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

final class TargetedLockoutAlert extends RecoverbullAttemptAlert {
  final String backupIdHash;
  const TargetedLockoutAlert({required this.backupIdHash});
}

enum ServicePressureKind { serviceBusy, mapNearlyFull }

final class ServicePressureAlert extends RecoverbullAttemptAlert {
  final ServicePressureKind kind;
  const ServicePressureAlert(this.kind);
}

final class AttemptMonitoringUnavailableAlert extends RecoverbullAttemptAlert {
  final Duration? since;
  const AttemptMonitoringUnavailableAlert({required this.since});
}

final class CountersWipedAlert extends RecoverbullAttemptAlert {
  final DateTime wipedAt;
  const CountersWipedAlert({required this.wipedAt});
}
