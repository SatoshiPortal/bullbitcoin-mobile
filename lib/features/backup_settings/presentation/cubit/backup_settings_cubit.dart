import 'package:bb_mobile/features/backup_settings/domain/usecases/get_default_wallet_metadata_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_settings_state.dart';
part 'backup_settings_cubit.freezed.dart';

class BackupSettingsCubit extends Cubit<BackupSettingsState> {
  final GetDefaultWalletMetadataUsecase getDefaultWalletMetadataUsecase;
  BackupSettingsCubit({required this.getDefaultWalletMetadataUsecase})
      : super(BackupSettingsState());

  Future<void> checkBackupStatus() async {
    try {
      emit(state.copyWith(loading: true));
      //Todo; add logic to check if the backup is tested in wallet metadata
      // For now, we will just set the default values
      await getDefaultWalletMetadataUsecase.execute();
      emit(
        state.copyWith(
          isDefaultPhysicalBackupTested: false,
          isDefaultEncryptedBackupTested: false,
          loading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false));
    }
  }
}
