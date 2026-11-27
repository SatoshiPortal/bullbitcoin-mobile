import 'package:backup_storage/backup_storage.dart' show BackupDestination;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/backup_metadata_failure.dart';
import '../domain/entities/backup_confirmation.dart';
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

/// The user chose a destination and wallets and the account behind the grant is
/// known, but nothing was selected for sending yet: the user must confirm the
/// provider, the account and the wallets, or cancel and nothing is sent.
final class BackupMetadataSettingsConfirming
    extends BackupMetadataSettingsState {
  final BackupRunStatus status;
  final BackupConfirmation confirmation;
  final Set<String> groups;

  const BackupMetadataSettingsConfirming(
    this.status,
    this.confirmation,
    this.groups,
  );

  BackupDestination get destination => confirmation.destination;
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

  /// Turning on, step one: stores the destination and the account the user
  /// authorized, with no wallet selected, so nothing can be sent. A failure
  /// stops here: there is no backup after a failed configuration. Success
  /// moves to [BackupMetadataSettingsConfirming].
  Future<void> turnOn({
    required BackupDestination destination,
    required Set<String> groups,
  }) async {
    if (isClosed || state is BackupMetadataSettingsLoading) return;
    emit(BackupMetadataSettingsLoading(_lastStatus));
    final staged = await _configure.stage(destination, groups);
    if (isClosed) return;
    final confirmation = switch (staged) {
      Ok(:final value) => value,
      Err(:final failure) => () {
        emit(BackupMetadataSettingsFailed(failure, _lastStatus));
        return null;
      }(),
    };
    if (confirmation == null) return;
    final status = await _status.execute();
    if (isClosed) return;
    switch (status) {
      case Ok(:final value):
        _lastStatus = value;
        emit(BackupMetadataSettingsConfirming(value, confirmation, groups));
      case Err(:final failure):
        emit(BackupMetadataSettingsFailed(failure, _lastStatus));
    }
  }

  /// Turning on, step two: the user confirmed. Selects the wallets on the
  /// confirmed account, then backs up. A failed selection sends nothing.
  Future<void> confirm() async {
    final current = state;
    if (current is! BackupMetadataSettingsConfirming || isClosed) return;
    emit(BackupMetadataSettingsLoading(current.status));
    final included = await _configure.include(
      current.groups,
      current.confirmation,
    );
    if (isClosed) return;
    if (included case Err(:final failure)) {
      emit(BackupMetadataSettingsFailed(failure, current.status));
      return;
    }
    emit(BackupMetadataSettingsReady(current.status));
    await backupNow();
  }

  /// The user declined the confirmation: turns the feature off again, nothing
  /// was sent and nothing of this installation is deleted.
  Future<void> decline() async {
    final current = state;
    if (current is! BackupMetadataSettingsConfirming || isClosed) return;
    emit(BackupMetadataSettingsLoading(current.status));
    final off = await _configure.discardStaged();
    if (isClosed) return;
    if (off case Err(:final failure)) {
      emit(BackupMetadataSettingsFailed(failure, current.status));
      return;
    }
    emit(BackupMetadataSettingsReady(current.status));
    await refresh();
  }

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
