import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_recovery_status_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_settings_cubit.freezed.dart';
part 'backup_settings_state.dart';

class BackupSettingsCubit extends Cubit<BackupSettingsState> {
  final GetWalletRecoveryStatusUsecase _getStatus;
  int _revision = 0;

  BackupSettingsCubit({required this._getStatus})
    : super(BackupSettingsState());

  Future<void> checkBackupStatus() async {
    final revision = ++_revision;
    emit(state.copyWith(status: BackupSettingsStatus.loading, failure: null));
    final result = await _getStatus.execute();
    if (isClosed || revision != _revision) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            isDefaultPhysicalBackupTested:
                value.isPhysicalBackupTested &&
                value.latestPhysicalBackup != null,
            isDefaultEncryptedBackupTested:
                value.isEncryptedVaultTested &&
                value.latestEncryptedBackup != null,
            lastPhysicalBackup: value.latestPhysicalBackup,
            lastEncryptedBackup: value.latestEncryptedBackup,
            status: BackupSettingsStatus.success,
            failure: null,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(status: BackupSettingsStatus.error, failure: failure),
        );
    }
  }
}
