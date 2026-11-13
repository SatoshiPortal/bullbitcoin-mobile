import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/read_backup_status_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:primitives/primitives.dart';
part 'backup_settings_cubit.freezed.dart';
part 'backup_settings_state.dart';

class BackupSettingsCubit extends Cubit<BackupSettingsState> {
  final ReadBackupStatusUsecase _read;
  BackupSettingsCubit(this._read) : super(BackupSettingsState());

  Future<void> checkBackupStatus() async {
    emit(state.copyWith(status: BackupSettingsStatus.loading));
    final result = await _read.execute();
    if (isClosed) return;
    switch (result) {
      case Err(:final failure):
        emit(
          state.copyWith(status: BackupSettingsStatus.error, failure: failure),
        );
      case Ok(:final value):
        emit(
          state.copyWith(
            status: BackupSettingsStatus.success,
            failure: null,
            isDefaultPhysicalBackupTested: value.physicalVerified,
            isDefaultEncryptedBackupTested: value.encryptedVerified,
            lastPhysicalBackup: value.physicalAt,
            lastEncryptedBackup: value.encryptedAt,
          ),
        );
    }
  }
}
