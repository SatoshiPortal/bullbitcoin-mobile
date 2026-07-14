enum BackupHealthPosture { recoverbullOnly, physicalOnly, both }

enum BackupHealthTrigger { scheduled, balanceMilestone }

enum BackupBalanceTier {
  none,
  oneMillion,
  tenMillion;

  bool isHigherThan(BackupBalanceTier other) => index > other.index;

  static BackupBalanceTier highest(
    BackupBalanceTier first,
    BackupBalanceTier second,
  ) => first.index >= second.index ? first : second;
}

class BackupHealthReminderRecord {
  final String masterFingerprint;
  final DateTime? lastAcknowledgedAt;
  final BackupBalanceTier highestHandledBalanceTier;
  final DateTime? pendingActionStartedAt;
  final BackupBalanceTier pendingActionBalanceTier;

  const BackupHealthReminderRecord({
    required this.masterFingerprint,
    this.lastAcknowledgedAt,
    this.highestHandledBalanceTier = BackupBalanceTier.none,
    this.pendingActionStartedAt,
    this.pendingActionBalanceTier = BackupBalanceTier.none,
  });

  BackupHealthReminderRecord copyWith({
    DateTime? lastAcknowledgedAt,
    BackupBalanceTier? highestHandledBalanceTier,
    DateTime? pendingActionStartedAt,
    bool clearPendingAction = false,
    BackupBalanceTier? pendingActionBalanceTier,
  }) => BackupHealthReminderRecord(
    masterFingerprint: masterFingerprint,
    lastAcknowledgedAt: lastAcknowledgedAt ?? this.lastAcknowledgedAt,
    highestHandledBalanceTier:
        highestHandledBalanceTier ?? this.highestHandledBalanceTier,
    pendingActionStartedAt: clearPendingAction
        ? null
        : pendingActionStartedAt ?? this.pendingActionStartedAt,
    pendingActionBalanceTier: clearPendingAction
        ? BackupBalanceTier.none
        : pendingActionBalanceTier ?? this.pendingActionBalanceTier,
  );
}

class BackupHealthDecision {
  final String masterFingerprint;
  final BackupHealthPosture posture;
  final BackupHealthTrigger trigger;
  final BackupBalanceTier currentBalanceTier;

  const BackupHealthDecision({
    required this.masterFingerprint,
    required this.posture,
    required this.trigger,
    required this.currentBalanceTier,
  });
}
