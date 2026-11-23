import 'package:backup_storage/backup_storage.dart' show BackupDestination;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/backup_metadata_failure.dart';
import '../domain/entities/backup_status.dart';
import '../domain/usecases/configure_backup_usecase.dart';
import '../domain/usecases/get_backup_status_usecase.dart';
import '../domain/usecases/run_backup_usecase.dart';

sealed class BackupMetadataSettingsState {
  const BackupMetadataSettingsState();
}

final class BackupMetadataSettingsInitial extends BackupMetadataSettingsState {
  const BackupMetadataSettingsInitial();
}

final class BackupMetadataSettingsLoading extends BackupMetadataSettingsState {
  final BackupRunStatus? previous;

  const BackupMetadataSettingsLoading(this.previous);
}

final class BackupMetadataSettingsReady extends BackupMetadataSettingsState {
  final BackupRunStatus status;

  const BackupMetadataSettingsReady(this.status);
}

final class BackupMetadataSettingsFailed extends BackupMetadataSettingsState {
  final BackupMetadataFailure failure;
  final BackupRunStatus? previous;

  const BackupMetadataSettingsFailed(this.failure, this.previous);
}

final class BackupMetadataSettingsCubit
    extends Cubit<BackupMetadataSettingsState> {
  final GetBackupStatusUsecase _status;
  final ConfigureBackupUsecase _configure;
  final RunBackupUsecase _run;
  BackupRunStatus? _lastStatus;

  BackupMetadataSettingsCubit(this._status, this._configure, this._run)
    : super(const BackupMetadataSettingsInitial());

  Future<void> refresh() => _perform(_status.execute);

  Future<void> backupNow() => _perform(_run.execute);

  Future<void> configure({
    required BackupDestination? destination,
    required Set<String> groups,
    bool deleteOwnedFiles = false,
  }) => _perform(() async {
    final configured = await _configure.execute(
      destination: destination,
      groups: groups,
      deleteOwnedFiles: deleteOwnedFiles,
    );
    return switch (configured) {
      Ok() => _status.execute(),
      Err(:final failure) => Err(failure),
    };
  });

  Future<void> _perform(
    Future<Result<BackupRunStatus, BackupMetadataFailure>> Function() action,
  ) async {
    if (isClosed || state is BackupMetadataSettingsLoading) return;
    emit(BackupMetadataSettingsLoading(_lastStatus));
    final result = await action();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        _lastStatus = value;
        emit(BackupMetadataSettingsReady(value));
      case Err(:final failure):
        emit(BackupMetadataSettingsFailed(failure, _lastStatus));
    }
  }
}
