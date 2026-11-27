import 'package:labels/backup.dart';
import 'package:backup_storage/backup_storage.dart' show BackupDestination;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/backup_metadata_failure.dart';
import '../domain/entities/discovered_backup.dart';
import '../domain/entities/restore_report.dart';
import '../domain/usecases/apply_restore_usecase.dart';
import '../domain/usecases/discover_backups_usecase.dart';
import '../domain/usecases/preview_restore_usecase.dart';

sealed class BackupMetadataRestoreState {
  const BackupMetadataRestoreState();
}

final class BackupMetadataRestoreInitial extends BackupMetadataRestoreState {
  const BackupMetadataRestoreInitial();
}

final class BackupMetadataRestoreLoading extends BackupMetadataRestoreState {
  const BackupMetadataRestoreLoading();
}

final class BackupMetadataRestoreDiscovered extends BackupMetadataRestoreState {
  final List<DiscoveredBackup> backups;

  const BackupMetadataRestoreDiscovered(this.backups);
}

final class BackupMetadataRestorePreview extends BackupMetadataRestoreState {
  final DiscoveredBackup backup;
  final MergePlan plan;
  final MergeChoices choices;

  const BackupMetadataRestorePreview(this.backup, this.plan, this.choices);
}

/// The outcome of an apply. It keeps what the apply used, so a partial result
/// can be completed: [apply] from this state recomputes the plan and runs
/// again, writing only what is still missing.
final class BackupMetadataRestoreReported extends BackupMetadataRestoreState {
  final DiscoveredBackup backup;
  final MergePlan plan;
  final MergeChoices choices;
  final RestoreReport report;

  const BackupMetadataRestoreReported(
    this.backup,
    this.plan,
    this.choices,
    this.report,
  );
}

final class BackupMetadataRestoreFailed extends BackupMetadataRestoreState {
  final BackupMetadataFailure failure;

  const BackupMetadataRestoreFailed(this.failure);
}

final class BackupMetadataRestoreCubit
    extends Cubit<BackupMetadataRestoreState> {
  final DiscoverBackupsUsecase _discover;
  final PreviewRestoreUsecase _preview;
  final ApplyRestoreUsecase _apply;

  BackupMetadataRestoreCubit(this._discover, this._preview, this._apply)
    : super(const BackupMetadataRestoreInitial());

  Future<void> discover(BackupDestination destination) => _perform(
    () => _discover.execute(destination),
    BackupMetadataRestoreDiscovered.new,
    current: (backups) => backups.every((backup) => backup.scope.isCurrent),
  );

  Future<void> preview(DiscoveredBackup backup) => _perform(
    () => _preview.execute(backup),
    (plan) => BackupMetadataRestorePreview(backup, plan, MergeChoices({})),
    current: (_) => backup.scope.isCurrent,
  );

  void choose(LabelConflict conflict, ConflictResolution resolution) {
    if (isClosed) return;
    if (state
        case BackupMetadataRestorePreview(
          :final backup,
          :final plan,
          :final choices,
        )
        when plan.conflicts.contains(conflict)) {
      emit(
        BackupMetadataRestorePreview(
          backup,
          plan,
          MergeChoices({...choices.resolutions, conflict: resolution}),
        ),
      );
    }
  }

  /// Applies the previewed plan. From a reported result it first recomputes
  /// the plan from the labels as they are now, then applies again with the
  /// same choices: the way to complete a partial restore.
  Future<void> apply() async {
    final current = state;
    switch (current) {
      case BackupMetadataRestorePreview(
        :final backup,
        :final plan,
        :final choices,
      ):
        await _run(backup, plan, choices);
      case BackupMetadataRestoreReported(:final backup, :final choices):
        if (isClosed || state is BackupMetadataRestoreLoading) return;
        emit(const BackupMetadataRestoreLoading());
        final fresh = await _preview.execute(backup);
        if (isClosed) return;
        switch (fresh) {
          case Ok(:final value):
            await _run(backup, value, choices, loading: false);
          case Err(:final failure):
            emit(BackupMetadataRestoreFailed(failure));
        }
      default:
        return;
    }
  }

  Future<void> _run(
    DiscoveredBackup backup,
    MergePlan plan,
    MergeChoices choices, {
    bool loading = true,
  }) async {
    if (loading && (isClosed || state is BackupMetadataRestoreLoading)) return;
    if (loading) emit(const BackupMetadataRestoreLoading());
    final result = await _apply.execute(backup, plan, choices);
    if (isClosed) return;
    emit(
      result.fold(
        // A report is published only while the session it was written in is
        // still the live one.
        (report) => backup.scope.isCurrent
            ? BackupMetadataRestoreReported(backup, plan, choices, report)
            : const BackupMetadataRestoreFailed(
                BackupMetadataScopeChangedFailure(),
              ),
        BackupMetadataRestoreFailed.new,
      ),
    );
  }

  /// [current] is evaluated just before the state is emitted, so a lock that
  /// landed while the work was settling is never followed by its result.
  Future<void> _perform<T>(
    Future<Result<T, BackupMetadataFailure>> Function() action,
    BackupMetadataRestoreState Function(T) succeeded, {
    required bool Function(T) current,
  }) async {
    if (isClosed || state is BackupMetadataRestoreLoading) return;
    emit(const BackupMetadataRestoreLoading());
    final result = await action();
    if (isClosed) return;
    emit(
      result.fold(
        (value) => current(value)
            ? succeeded(value)
            : const BackupMetadataRestoreFailed(
                BackupMetadataScopeChangedFailure(),
              ),
        BackupMetadataRestoreFailed.new,
      ),
    );
  }
}
