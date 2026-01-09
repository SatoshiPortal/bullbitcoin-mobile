import 'package:bb_mobile/core/bitbox/data/datasources/bitbox_device_datasource.dart';
import 'package:bb_mobile/core/bitbox/data/repositories/bitbox_device_repository_impl.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/connect_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/get_bitbox_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/pair_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/scan_bitbox_devices_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/sign_psbt_bitbox_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/unlock_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/verify_address_bitbox_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:get_it/get_it.dart';

class BitBoxCoreLocator {
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<BitBoxDeviceDatasource>(
      () => BitBoxDeviceDatasource(),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<BitBoxDeviceRepository>(
      () => BitBoxDeviceRepositoryImpl(
        datasource: locator<BitBoxDeviceDatasource>(),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerLazySingleton<ScanBitBoxDevicesUsecase>(
      () => ScanBitBoxDevicesUsecase(
        repository: locator<BitBoxDeviceRepository>(),
      ),
    );

    locator.registerLazySingleton<ConnectBitBoxDeviceUsecase>(
      () => ConnectBitBoxDeviceUsecase(
        repository: locator<BitBoxDeviceRepository>(),
      ),
    );

    locator.registerLazySingleton<UnlockBitBoxDeviceUsecase>(
      () => UnlockBitBoxDeviceUsecase(
        repository: locator<BitBoxDeviceRepository>(),
      ),
    );

    locator.registerLazySingleton<PairBitBoxDeviceUsecase>(
      () => PairBitBoxDeviceUsecase(
        repository: locator<BitBoxDeviceRepository>(),
      ),
    );

    locator.registerLazySingleton<VerifyAddressBitBoxUsecase>(
      () => VerifyAddressBitBoxUsecase(
        repository: locator<BitBoxDeviceRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerLazySingleton<GetBitBoxWatchOnlyWalletUsecase>(
      () => GetBitBoxWatchOnlyWalletUsecase(
        repository: locator<BitBoxDeviceRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerLazySingleton<SignPsbtBitBoxUsecase>(
      () => SignPsbtBitBoxUsecase(
        repository: locator<BitBoxDeviceRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }
}
