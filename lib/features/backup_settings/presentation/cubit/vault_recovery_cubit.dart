import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class VaultRecoveryState {
  final bool busy;
  final VaultBackupRecovery? result;
  final BackupSettingsFailure? failure;
  const VaultRecoveryState({this.busy = false, this.result, this.failure});
}

class VaultRecoveryCubit extends Cubit<VaultRecoveryState> {
  final RecoverVaultsUsecase _recover;
  int _request = 0;
  VaultRecoveryCubit(this._recover) : super(const VaultRecoveryState());

  void reset() {
    _request++;
    emit(const VaultRecoveryState());
  }

  Future<void> search({String? words}) async {
    if (state.busy) return;
    final request = ++_request;
    emit(const VaultRecoveryState(busy: true));
    final result = await _recover.execute(
      words: words,
      abandoned: () => isClosed || request != _request,
    );
    if (isClosed || request != _request) return;
    emit(switch (result) {
      Err(:final failure) => VaultRecoveryState(failure: failure),
      Ok(:final value) => VaultRecoveryState(
        result: value,
        failure: value?.failure == null
            ? null
            : BackupSettingsFailure.fromDataBackup(value!.failure!),
      ),
    });
  }
}
