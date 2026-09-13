import 'dart:typed_data';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/create_vault_recovery_kit_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_kit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class VaultRecoveryKitState {
  final bool busy;
  final BackupSettingsFailure? failure;
  const VaultRecoveryKitState({this.busy = false, this.failure});
}

final class VaultRecoveryKitCubit extends Cubit<VaultRecoveryKitState> {
  final CreateVaultRecoveryKitUsecase _create;
  VaultRecoveryKitCubit(this._create) : super(const VaultRecoveryKitState());
  Future<Uint8List?> create(
    VaultRecoveryKit kit,
    VaultRecoveryKitCopy copy,
  ) async {
    if (state.busy) return null;
    emit(const VaultRecoveryKitState(busy: true));
    final result = await _create.execute(kit, copy);
    if (isClosed) return null;
    switch (result) {
      case Ok(:final value):
        emit(const VaultRecoveryKitState());
        return value;
      case Err(:final failure):
        emit(VaultRecoveryKitState(failure: failure));
        return null;
    }
  }
}
