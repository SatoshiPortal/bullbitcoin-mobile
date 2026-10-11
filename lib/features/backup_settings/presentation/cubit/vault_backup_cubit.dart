import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_vault_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_status.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class VaultBackupState {
  const VaultBackupState();
}

final class VaultBackupLoading extends VaultBackupState {
  const VaultBackupLoading();
}

final class VaultBackupFailed extends VaultBackupState {
  final BackupSettingsFailure failure;
  const VaultBackupFailed(this.failure);
}

final class VaultBackupLoaded extends VaultBackupState {
  final VaultBackupStatus data;
  final bool busy;
  final BackupSettingsFailure? failure;
  final WalletBackupInspection? inspection;
  const VaultBackupLoaded(
    this.data, {
    this.busy = false,
    this.failure,
    this.inspection,
  });
}

class VaultBackupCubit extends Cubit<VaultBackupState> {
  final LoadVaultBackupUsecase _load;
  final CheckVaultServerBackupUsecase _check;
  final VerifyVaultDescriptorBackupUsecase _verify;
  int _request = 0;
  VaultBackupCubit(this._load, this._check, this._verify)
    : super(const VaultBackupLoading());

  Future<void> load(String walletId) async {
    final request = ++_request;
    emit(const VaultBackupLoading());
    final result = await _load.execute(walletId);
    if (isClosed || request != _request) return;
    emit(switch (result) {
      Ok(:final value) => VaultBackupLoaded(value),
      Err(:final failure) => VaultBackupFailed(failure),
    });
  }

  Future<void> checkServer() async {
    final current = state;
    if (current is! VaultBackupLoaded || current.busy) return;
    final request = ++_request;
    emit(
      VaultBackupLoaded(
        current.data,
        busy: true,
        inspection: current.inspection,
      ),
    );
    final result = await _check.execute(current.data.record);
    if (isClosed || request != _request) return;
    emit(switch (result) {
      Ok(:final value) => VaultBackupLoaded(
        current.data.withRecord(value.record),
        inspection: value.inspection,
      ),
      Err(:final failure) => VaultBackupLoaded(
        current.data,
        failure: failure,
        inspection: current.inspection,
      ),
    });
  }

  Future<void> verifyDescriptor([String? source]) async {
    final current = state;
    if (current is! VaultBackupLoaded || current.busy) return;
    final request = ++_request;
    emit(
      VaultBackupLoaded(
        current.data,
        busy: true,
        inspection: current.inspection,
      ),
    );
    final result = await _verify.execute(current.data.record, source: source);
    if (isClosed || request != _request) return;
    emit(switch (result) {
      Ok(value: final date?) => VaultBackupLoaded(
        current.data.withRecord(
          current.data.record.copyWith(descriptorTestedAt: date),
        ),
        inspection: current.inspection,
      ),
      Ok(value: null) => VaultBackupLoaded(
        current.data,
        inspection: current.inspection,
      ),
      Err(:final failure) => VaultBackupLoaded(
        current.data,
        failure: failure,
        inspection: current.inspection,
      ),
    });
  }
}
