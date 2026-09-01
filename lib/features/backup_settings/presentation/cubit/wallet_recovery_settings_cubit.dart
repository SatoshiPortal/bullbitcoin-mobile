import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_recovery_status_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class WalletRecoverySettingsState {
  final DateTime? lastPhysicalBackup;
  final DateTime? lastEncryptedBackup;
  final bool loaded;
  final BackupSettingsFailure? failure;

  const WalletRecoverySettingsState({
    this.lastPhysicalBackup,
    this.lastEncryptedBackup,
    this.loaded = false,
    this.failure,
  });

  bool get hasPhysicalBackup => lastPhysicalBackup != null;
  bool get hasEncryptedBackup => lastEncryptedBackup != null;
  bool get hasNoBackup => loaded && !hasPhysicalBackup && !hasEncryptedBackup;
}

final class WalletRecoverySettingsCubit
    extends Cubit<WalletRecoverySettingsState> {
  final GetWalletRecoveryStatusUsecase _getStatus;

  WalletRecoverySettingsCubit(this._getStatus)
    : super(const WalletRecoverySettingsState());

  Future<void> load() async {
    final result = await _getStatus.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          WalletRecoverySettingsState(
            lastPhysicalBackup: value.lastPhysicalBackup,
            lastEncryptedBackup: value.lastEncryptedBackup,
            loaded: true,
          ),
        );
      case Err(:final failure):
        emit(WalletRecoverySettingsState(failure: failure));
    }
  }
}
