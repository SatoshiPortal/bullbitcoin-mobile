import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
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

      final defaultWallets = await _getWalletsUsecase.execute(
        onlyDefaults: true,
      );
      if (defaultWallets.isEmpty) {
        emit(state.copyWith(loading: false));
        return;
      }
      emit(
        state.copyWith(
          isDefaultPhysicalBackupTested:
              defaultWallets.every((e) => e.isPhysicalBackupTested),
          isDefaultEncryptedBackupTested:
              defaultWallets.every((e) => e.isEncryptedVaultTested),
          lastPhysicalBackup: defaultWallets
              .firstWhere((e) => e.network == Network.bitcoinMainnet)
              .latestPhysicalBackup,
          lastEncryptedBackup: defaultWallets
              .firstWhere((e) => e.network == Network.bitcoinMainnet)
              .latestEncryptedBackup,
          loading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false));
    }
  }
}
