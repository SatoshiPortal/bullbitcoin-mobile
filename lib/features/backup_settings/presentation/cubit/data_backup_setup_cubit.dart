import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/update_data_backup_lifecycle_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DataBackupSetupState {
  final bool loading;
  final WalletBackupControl? control;
  final BackupSettingsFailure? failure;
  const DataBackupSetupState({
    this.loading = false,
    this.control,
    this.failure,
  });
}

/// Presents the outcome of the app scope's existing consent/readiness gate.
class DataBackupSetupCubit extends Cubit<DataBackupSetupState> {
  final UpdateDataBackupLifecycleUsecase _lifecycle;
  bool _ready = false;
  bool _foreground = false;
  bool _closing = false;
  int _request = 0;
  DataBackupSetupCubit(this._lifecycle) : super(const DataBackupSetupState());

  Future<void> update({required bool ready, required bool foreground}) async {
    if (isClosed || _closing) return;
    _ready = ready;
    _foreground = foreground;
    final request = ++_request;
    emit(DataBackupSetupState(loading: ready && foreground));
    final result = await _lifecycle.execute(
      ready: ready,
      foreground: foreground,
    );
    if (isClosed || _closing || request != _request) return;
    emit(switch (result) {
      Ok(:final value) => DataBackupSetupState(control: value),
      Err(:final failure) => DataBackupSetupState(failure: failure),
    });
  }

  Future<void> retry() => update(ready: _ready, foreground: _foreground);

  @override
  Future<void> close() async {
    _closing = true;
    _request++;
    final _ = await _lifecycle.execute(ready: false, foreground: false);
    return super.close();
  }
}
