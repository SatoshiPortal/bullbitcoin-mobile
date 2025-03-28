import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_default_wallet_metadata_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/locator.dart';

class BackupSettingsLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<GetDefaultWalletMetadataUsecase>(
      () => GetDefaultWalletMetadataUsecase(
        walletMetadataRepository: locator<WalletMetadataRepository>(),
      ),
    );
    // Blocs
    locator.registerFactory<BackupSettingsCubit>(
      () => BackupSettingsCubit(
        getDefaultWalletMetadataUsecase:
            locator<GetDefaultWalletMetadataUsecase>(),
      ),
    );
  }
}
