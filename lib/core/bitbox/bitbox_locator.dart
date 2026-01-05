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
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';

class BitBoxCoresl {
  static void registerDatasources() {
    sl.registerLazySingleton<BitBoxDeviceDatasource>(
      () => BitBoxDeviceDatasource(),
    );
  }

  static void registerRepositories() {
    sl.registerLazySingleton<BitBoxDeviceRepository>(
      () =>
          BitBoxDeviceRepositoryImpl(datasource: sl<BitBoxDeviceDatasource>()),
    );
  }

  static void registerUsecases() {
    sl.registerLazySingleton<ScanBitBoxDevicesUsecase>(
      () => ScanBitBoxDevicesUsecase(repository: sl<BitBoxDeviceRepository>()),
    );

    sl.registerLazySingleton<ConnectBitBoxDeviceUsecase>(
      () =>
          ConnectBitBoxDeviceUsecase(repository: sl<BitBoxDeviceRepository>()),
    );

    sl.registerLazySingleton<UnlockBitBoxDeviceUsecase>(
      () => UnlockBitBoxDeviceUsecase(repository: sl<BitBoxDeviceRepository>()),
    );

    sl.registerLazySingleton<PairBitBoxDeviceUsecase>(
      () => PairBitBoxDeviceUsecase(repository: sl<BitBoxDeviceRepository>()),
    );

    sl.registerLazySingleton<VerifyAddressBitBoxUsecase>(
      () => VerifyAddressBitBoxUsecase(
        repository: sl<BitBoxDeviceRepository>(),
        settingsRepository: sl<SettingsRepository>(),
      ),
    );

    sl.registerLazySingleton<GetBitBoxWatchOnlyWalletUsecase>(
      () => GetBitBoxWatchOnlyWalletUsecase(
        repository: sl<BitBoxDeviceRepository>(),
        settingsRepository: sl<SettingsRepository>(),
      ),
    );

    sl.registerLazySingleton<SignPsbtBitBoxUsecase>(
      () => SignPsbtBitBoxUsecase(
        repository: sl<BitBoxDeviceRepository>(),
        settingsRepository: sl<SettingsRepository>(),
      ),
    );
  }
}
