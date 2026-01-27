import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_backup_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';

class TestWalletBackupDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerLazySingleton<LoadWalletsForNetworkUsecase>(
      () => LoadWalletsForNetworkUsecase(
        walletRepository: sl(),
        settingsRepository: sl(),
      ),
    );
    sl.registerLazySingleton<GetMnemonicFromFingerprintUsecase>(
      () => GetMnemonicFromFingerprintUsecase(
        seedRepository: sl(),
      ),
    );
    sl.registerFactory<CheckBackupUsecase>(
      () => CheckBackupUsecase(
        walletRepository: sl(),
        settingsRepository: sl(),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {}
}
