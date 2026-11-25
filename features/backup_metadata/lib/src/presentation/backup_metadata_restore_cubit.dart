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

final class BackupMetadataRestoreReported extends BackupMetadataRestoreState {
  final RestoreReport report;

  const BackupMetadataRestoreReported(this.report);
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
  );

  Future<void> preview(DiscoveredBackup backup) => _perform(
    () => _preview.execute(backup),
    (plan) => BackupMetadataRestorePreview(backup, plan, MergeChoices({})),
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

  Future<void> apply() async {
    if (state case BackupMetadataRestorePreview(
      :final backup,
      :final plan,
      :final choices,
    )) {
      await _perform(
        () => _apply.execute(backup, plan, choices),
        BackupMetadataRestoreReported.new,
      );
    }
  }

  Future<void> _perform<T>(
    Future<Result<T, BackupMetadataFailure>> Function() action,
    BackupMetadataRestoreState Function(T) succeeded,
  ) async {
    if (isClosed || state is BackupMetadataRestoreLoading) return;
    emit(const BackupMetadataRestoreLoading());
    final result = await action();
    if (isClosed) return;
    emit(result.fold(succeeded, BackupMetadataRestoreFailed.new));
  }
}
