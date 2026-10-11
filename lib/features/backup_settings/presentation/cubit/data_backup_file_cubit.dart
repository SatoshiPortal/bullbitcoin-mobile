import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_data_backup_files_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class DataBackupFileState {
  const DataBackupFileState();
  bool get busy => false;
}

final class DataBackupFileInitial extends DataBackupFileState {
  const DataBackupFileInitial();
}

final class DataBackupFileWorking extends DataBackupFileState {
  const DataBackupFileWorking();
  @override
  bool get busy => true;
}

final class DataBackupFileExported extends DataBackupFileState {
  const DataBackupFileExported();
}

final class DataBackupFileFailed extends DataBackupFileState {
  final BackupSettingsFailure failure;
  const DataBackupFileFailed(this.failure);
}

final class DataBackupFilePreview extends DataBackupFileState {
  final WalletBackupFileComparison comparison;
  final WalletBackupImportSource source;
  final WalletBackupRecovery? result;
  final BackupSettingsFailure? failure;
  @override
  final bool busy;
  const DataBackupFilePreview({
    required this.comparison,
    this.source = WalletBackupImportSource.file,
    this.result,
    this.failure,
    this.busy = false,
  });
}

class DataBackupFileCubit extends Cubit<DataBackupFileState> {
  final ExportDataBackupFileUsecase _export;
  final InspectDataBackupFileUsecase _inspect;
  final RecoverDataBackupFileUsecase _recover;
  String? _validatedSource;
  int _request = 0;
  DataBackupFileCubit(this._export, this._inspect, this._recover)
    : super(const DataBackupFileInitial());

  void reset() {
    _request++;
    _validatedSource = null;
    if (!isClosed) emit(const DataBackupFileInitial());
  }

  Future<void> export(
    WalletBackupFileFormat format, {
    bool confirmed = false,
  }) async {
    if (state.busy) return;
    reset();
    final request = ++_request;
    emit(const DataBackupFileWorking());
    final result = await _export.execute(format, confirmed: confirmed);
    if (isClosed || request != _request) return;
    emit(switch (result) {
      Ok(:final value) =>
        value ? const DataBackupFileExported() : const DataBackupFileInitial(),
      Err(:final failure) => DataBackupFileFailed(failure),
    });
  }

  Future<void> inspect() async {
    if (state.busy) return;
    reset();
    final request = ++_request;
    emit(const DataBackupFileWorking());
    final result = await _inspect.execute();
    if (isClosed || request != _request) return;
    switch (result) {
      case Ok(value: final value?):
        _validatedSource = value.source;
        emit(DataBackupFilePreview(comparison: value.comparison));
      case Ok(value: null):
        emit(const DataBackupFileInitial());
      case Err(:final failure):
        emit(DataBackupFileFailed(failure));
    }
  }

  Future<void> recover(
    WalletBackupImportSource source, {
    required bool confirmed,
  }) async {
    final file = _validatedSource;
    final current = state;
    if (current is! DataBackupFilePreview ||
        current.busy ||
        !confirmed ||
        file == null) {
      return;
    }
    final comparison = current.comparison;
    final request = ++_request;
    emit(
      DataBackupFilePreview(busy: true, comparison: comparison, source: source),
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
          DataBackupFilePreview(
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
        emit(
          DataBackupFilePreview(
            comparison: comparison,
            source: source,
            failure: failure,
          ),
        );
    }
  }

  @override
  Future<void> close() {
    _validatedSource = null;
    _request++;
    return super.close();
  }
}
