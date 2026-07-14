part of 'backup_health_reminder_cubit.dart';

sealed class BackupHealthReminderState {
  const BackupHealthReminderState();
}

final class BackupHealthReminderHidden extends BackupHealthReminderState {
  const BackupHealthReminderHidden();
}

final class BackupHealthReminderVisible extends BackupHealthReminderState {
  final BackupHealthDecision decision;
  final bool isSaving;
  final BackupSettingsFailure? failure;

  const BackupHealthReminderVisible({
    required this.decision,
    this.isSaving = false,
    this.failure,
  });

  BackupHealthReminderVisible copyWith({
    bool? isSaving,
    BackupSettingsFailure? failure,
    bool clearFailure = false,
  }) => BackupHealthReminderVisible(
    decision: decision,
    isSaving: isSaving ?? this.isSaving,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}
