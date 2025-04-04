import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_settings_state.dart';
part 'backup_settings_cubit.freezed.dart';

class BackupSettingsCubit extends Cubit<BackupSettingsState> {
  BackupSettingsCubit({
    required GetWalletsUsecase getWalletsUsecase,
  })  : _getWalletsUsecase = getWalletsUsecase,
        super(BackupSettingsState());

  final GetWalletsUsecase _getWalletsUsecase;

  Future<void> checkBackupStatus() async {
    try {
      emit(state.copyWith(loading: true));
      //Todo; add logic to check if the backup is tested in wallet metadata
      // For now, we will just set the default values
      final defaultBitcoinWallets = await _getWalletsUsecase.execute(
        onlyBitcoin: true,
        onlyDefaults: true,
        sync: false,
      );

      if (defaultBitcoinWallets.isEmpty) {
        emit(state.copyWith(loading: false));
        return;
      }
      // There should be only one default Bitcoin wallet
      final defaultWallet = defaultBitcoinWallets.first;
      emit(
        state.copyWith(
          isDefaultPhysicalBackupTested: defaultWallet.isPhysicalBackupTested,
          isDefaultEncryptedBackupTested: defaultWallet.isEncryptedVaultTested,
          lastPhysicalBackup: defaultWallet.latestPhysicalBackup,
          lastEncryptedBackup: defaultWallet.latestEncryptedBackup,
          loading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false));
    }
  }
}
