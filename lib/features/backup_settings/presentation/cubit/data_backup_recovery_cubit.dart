import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_data_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class DataBackupRecoveryState {
  const DataBackupRecoveryState();
  bool get busy;
}

final class DataBackupRecoveryInitial extends DataBackupRecoveryState {
  @override
  final bool busy;
  final BackupSettingsFailure? failure;
  const DataBackupRecoveryInitial({this.busy = false, this.failure});
}

final class DataBackupRecoveryPreview extends DataBackupRecoveryState {
  final WalletBackupInspection inspection;
  @override
  final bool busy;
  final WalletBackupRecovery? result;
  final BackupSettingsFailure? failure;
  const DataBackupRecoveryPreview(
    this.inspection, {
    this.busy = false,
    this.result,
    this.failure,
  });
}

class DataBackupRecoveryCubit extends Cubit<DataBackupRecoveryState> {
  final InspectDataBackupUsecase _inspect;
  final RecoverDataBackupUsecase _recover;
  int _request = 0;
  DataBackupRecoveryCubit(
    this._inspect,
    this._recover, {
    WalletBackupInspection? inspection,
  }) : super(
         inspection == null
             ? const DataBackupRecoveryInitial()
             : DataBackupRecoveryPreview(inspection),
       );

  void reset() {
    _request++;
    emit(const DataBackupRecoveryInitial());
  }

  Future<void> inspect({String? words}) async {
    if (state.busy) return;
    final request = ++_request;
    emit(const DataBackupRecoveryInitial(busy: true));
    final result = await _inspect.execute(words: words);
    if (isClosed || request != _request) return;
    emit(switch (result) {
      Ok(:final value) => DataBackupRecoveryPreview(value),
      Err(:final failure) => DataBackupRecoveryInitial(failure: failure),
    });
  }

  Future<void> recover({
    bool enableAfterRecovery = false,
    String? words,
  }) async {
    final current = state;
    if (current is! DataBackupRecoveryPreview ||
        current.busy ||
        current.inspection.snapshot == null) {
      return;
    }
    final request = ++_request;
    emit(DataBackupRecoveryPreview(current.inspection, busy: true));
    final result = await _recover.execute(
      current.inspection,
      confirmed: true,
      words: words,
      enableAfterRecovery: enableAfterRecovery,
    );
    if (isClosed || request != _request) return;
    emit(switch (result) {
      Ok(:final value) => DataBackupRecoveryPreview(
        current.inspection,
        result: value,
        failure: value.complete
            ? null
            : value.failure == null
            ? const BackupSettingsRecoveryIncompleteFailure()
            : BackupSettingsFailure.fromDataBackup(value.failure!),
      ),
      Err(:final failure) => DataBackupRecoveryPreview(
        current.inspection,
        failure: failure,
      ),
    });
  }
}
