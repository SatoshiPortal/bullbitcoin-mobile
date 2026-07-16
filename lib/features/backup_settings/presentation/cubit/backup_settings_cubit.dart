import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/entities/backup_settings_snapshot.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/backup_wallet_metadata_now_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/delete_remote_wallet_metadata_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/load_backup_settings_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_metadata_backup_enabled_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_settings_cubit.freezed.dart';
part 'backup_settings_state.dart';

class BackupSettingsCubit extends Cubit<BackupSettingsState> {
  final LoadBackupSettingsUsecase _loadSettings;
  final SetWalletMetadataBackupEnabledUsecase _setMetadataBackupEnabled;
  final BackupWalletMetadataNowUsecase _backupMetadataNow;
  final DeleteRemoteWalletMetadataBackupUsecase _deleteRemoteMetadata;

  BackupSettingsCubit({
    required this._loadSettings,
    required this._setMetadataBackupEnabled,
    required this._backupMetadataNow,
    required this._deleteRemoteMetadata,
  }) : super(BackupSettingsState());

  Future<void> checkBackupStatus() async {
    if (state.metadataBackupBusy ||
        state.status == BackupSettingsStatus.loading) {
      return;
    }
    emit(
      state.copyWith(
        status: BackupSettingsStatus.loading,
        metadataActionStatus: WalletMetadataBackupActionStatus.idle,
        failure: null,
      ),
    );
    final result = await _loadSettings.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          _withMetadataSettings(
            state.copyWith(
              isDefaultPhysicalBackupTested:
                  value.isDefaultPhysicalBackupTested,
              isDefaultEncryptedBackupTested:
                  value.isDefaultEncryptedBackupTested,
              lastPhysicalBackup: value.lastPhysicalBackup,
              lastEncryptedBackup: value.lastEncryptedBackup,
              status: BackupSettingsStatus.success,
              failure: null,
            ),
            value.walletMetadata,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(status: BackupSettingsStatus.error, failure: failure),
        );
    }
  }

  Future<void> setMetadataBackupEnabled({
    required bool enabled,
    required bool disclosureAccepted,
  }) async {
    if (state.metadataBackupBusy ||
        state.status == BackupSettingsStatus.loading) {
      return;
    }
    emit(
      state.copyWith(
        metadataBackupBusy: true,
        metadataActionStatus: WalletMetadataBackupActionStatus.idle,
      ),
    );
    final result = await _setMetadataBackupEnabled.execute(
      enabled: enabled,
      disclosureAccepted: disclosureAccepted,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          _withMetadataSettings(
            state.copyWith(metadataBackupBusy: false, failure: null),
            value,
          ),
        );
      case Err(:final failure):
        _emitMetadataFailure(failure);
    }
  }

  Future<void> backupMetadataNow() async {
    if (state.metadataBackupBusy ||
        state.status == BackupSettingsStatus.loading) {
      return;
    }
    emit(
      state.copyWith(
        metadataBackupBusy: true,
        metadataActionStatus: WalletMetadataBackupActionStatus.idle,
      ),
    );
    final result = await _backupMetadataNow.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        final actionStatus = switch (value.status) {
          WalletMetadataBackupNowStatus.saved =>
            WalletMetadataBackupActionStatus.saved,
          WalletMetadataBackupNowStatus.unchanged =>
            WalletMetadataBackupActionStatus.unchanged,
          WalletMetadataBackupNowStatus.notReady =>
            WalletMetadataBackupActionStatus.notReady,
        };
        emit(
          _withMetadataSettings(
            state.copyWith(
              metadataBackupBusy: false,
              metadataActionStatus: actionStatus,
              failure: null,
            ),
            value.settings,
          ),
        );
      case Err(:final failure):
        _emitMetadataFailure(failure);
    }
  }

  Future<void> deleteRemoteMetadata() async {
    if (state.metadataBackupBusy || state.metadataBackupEnabled) return;
    emit(
      state.copyWith(
        metadataBackupBusy: true,
        metadataActionStatus: WalletMetadataBackupActionStatus.idle,
        failure: null,
      ),
    );
    final result = await _deleteRemoteMetadata.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          _withMetadataSettings(
            state.copyWith(
              metadataActionStatus: WalletMetadataBackupActionStatus.deleted,
            ),
            value,
          ),
        );
      case Err(:final failure):
        _emitMetadataFailure(failure);
    }
  }

  BackupSettingsState _withMetadataSettings(
    BackupSettingsState current,
    WalletMetadataBackupSettingsSnapshot metadata,
  ) {
    return current.copyWith(
      metadataBackupEnabled: metadata.enabled,
      metadataBackupDirty: metadata.dirty,
      metadataBackupBlocked: metadata.blocked,
      metadataBackupHasRemote: metadata.hasRemoteBackup,
      metadataBackupLastVerifiedAt: metadata.lastVerifiedAt,
      metadataBackupBusy: false,
    );
  }

  void _emitMetadataFailure(BackupSettingsFailure failure) {
    emit(
      state.copyWith(
        metadataBackupBusy: false,
        metadataActionStatus: WalletMetadataBackupActionStatus.failed,
        failure: failure,
      ),
    );
  }
}
