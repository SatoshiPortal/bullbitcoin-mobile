import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_data_backup_files_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class DataBackupFileState {
  final bool busy;
  final bool exported;
  final WalletBackupFileComparison? comparison;
  final WalletBackupRecovery? result;
  final WalletBackupImportSource? source;
  final BackupSettingsFailure? failure;
  const DataBackupFileState({
    this.busy = false,
    this.exported = false,
    this.comparison,
    this.result,
    this.failure,
    this.source,
  });
}

class DataBackupFileCubit extends Cubit<DataBackupFileState> {
  final ExportDataBackupFileUsecase _export;
  final InspectDataBackupFileUsecase _inspect;
  final RecoverDataBackupFileUsecase _recover;
  String? _validatedSource;
  int _request = 0;
  DataBackupFileCubit(this._export, this._inspect, this._recover)
    : super(const DataBackupFileState());

  void reset() {
    _request++;
    _validatedSource = null;
    if (!isClosed) emit(const DataBackupFileState());
  }

  Future<void> export(
    WalletBackupFileFormat format, {
    bool confirmed = false,
  }) async {
    if (state.busy) return;
    reset();
    final request = ++_request;
    emit(const DataBackupFileState(busy: true));
    final result = await _export.execute(format, confirmed: confirmed);
    if (isClosed || request != _request) return;
    emit(switch (result) {
      Ok(:final value) => DataBackupFileState(exported: value),
      Err(:final failure) => DataBackupFileState(failure: failure),
    });
  }

  Future<void> inspect() async {
    if (state.busy) return;
    reset();
    final request = ++_request;
    emit(const DataBackupFileState(busy: true));
    final result = await _inspect.execute();
    if (isClosed || request != _request) return;
    switch (result) {
      case Ok(value: final value?):
        _validatedSource = value.source;
        emit(DataBackupFileState(comparison: value.comparison));
      case Ok(value: null):
        emit(const DataBackupFileState());
      case Err(:final failure):
        emit(DataBackupFileState(failure: failure));
    }
  }

  Future<void> recover(
    WalletBackupImportSource source, {
    required bool confirmed,
  }) async {
    final file = _validatedSource;
    final comparison = state.comparison;
    if (state.busy || !confirmed || file == null || comparison == null) return;
    final request = ++_request;
    emit(
      DataBackupFileState(busy: true, comparison: comparison, source: source),
    );
    final result = await _recover.execute(
      file,
      comparison: comparison,
      source: source,
      confirmed: confirmed,
    );
    if (isClosed || request != _request) return;
    switch (result) {
      case Ok(:final value):
        if (value.complete) _validatedSource = null;
        emit(
          DataBackupFileState(
            comparison: comparison,
            result: value,
            source: source,
            failure: value.complete
                ? null
                : value.failure == null
                ? const BackupSettingsRecoveryIncompleteFailure()
                : BackupSettingsFailure.fromDataBackup(value.failure!),
          ),
        );
      case Err(:final failure):
        emit(DataBackupFileState(comparison: comparison, failure: failure));
    }
  }

  @override
  Future<void> close() {
    _validatedSource = null;
    _request++;
    return super.close();
  }
}
