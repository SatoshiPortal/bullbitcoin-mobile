/// What a wallet can currently recover from.
///
/// There is no zero-backup value on purpose: that state is owned by the
/// every-launch backup warning and by the Backup Settings hero, never by a
/// reminder. [BackupHealthPosture.of] returns null for it.
enum BackupHealthPosture {
  recoverbullOnly,
  physicalOnly,
  both;

  /// How long the same advice waits before it is worth repeating.
  ///
  /// A vault-only wallet has a single recovery path that depends on someone
  /// else, so it is asked more often than a wallet that already holds words.
  Duration get reminderInterval => switch (this) {
    BackupHealthPosture.recoverbullOnly => const Duration(days: 90),
    BackupHealthPosture.physicalOnly ||
    BackupHealthPosture.both => const Duration(days: 365),
  };

  /// Whether the one action for this posture is creating a physical backup,
  /// as opposed to testing the physical backup that already exists.
  bool get urgesPhysicalBackup => this == BackupHealthPosture.recoverbullOnly;

  /// The posture for a set of verified backups, or null when nothing is
  /// backed up.
  static BackupHealthPosture? of({
    required bool isEncryptedVaultTested,
    required bool isPhysicalBackupTested,
  }) => switch ((isEncryptedVaultTested, isPhysicalBackupTested)) {
    (true, false) => recoverbullOnly,
    (false, true) => physicalOnly,
    (true, true) => both,
    (false, false) => null,
  };
}

enum BackupHealthTrigger { scheduled, balanceMilestone }

/// Whether advice anchored at [anchor] is due again at [now].
///
/// A missing anchor (a backup marked tested without a completion date) and a
/// clock that has moved backwards both count as due: repeating advice is
/// better than silently stopping.
bool isBackupReminderDue({
  required DateTime? anchor,
  required DateTime now,
  required Duration interval,
}) =>
    anchor == null ||
    anchor.isAfter(now) ||
    !now.isBefore(anchor.add(interval));

class BackupHealthReminderRecord {
  final String masterFingerprint;
  final DateTime? lastAcknowledgedAt;

  /// Set once the user has been told, once per wallet lifetime, that the
  /// balance reached the milestone. A balance dropping back below it never
  /// clears this.
  final bool crossedTenMillionSats;

  const BackupHealthReminderRecord({
    required this.masterFingerprint,
    this.lastAcknowledgedAt,
    this.crossedTenMillionSats = false,
  });

  BackupHealthReminderRecord copyWith({
    DateTime? lastAcknowledgedAt,
    bool? crossedTenMillionSats,
  }) => BackupHealthReminderRecord(
    masterFingerprint: masterFingerprint,
    lastAcknowledgedAt: lastAcknowledgedAt ?? this.lastAcknowledgedAt,
    crossedTenMillionSats: crossedTenMillionSats ?? this.crossedTenMillionSats,
  );
}

class BackupHealthDecision {
  final String masterFingerprint;
  final BackupHealthPosture posture;
  final BackupHealthTrigger trigger;

  /// When the physical backup was last tested, when it has been. Null for a
  /// vault-only wallet and for a tested backup with no recorded date; the UI
  /// must not claim a test date the app never observed.
  final DateTime? physicalBackupTestedAt;

  const BackupHealthDecision({
    required this.masterFingerprint,
    required this.posture,
    required this.trigger,
    this.physicalBackupTestedAt,
  });
}
