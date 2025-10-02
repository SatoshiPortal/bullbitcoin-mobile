import 'package:bb_mobile/core/ledger/data/datasources/ledger_device_datasource.dart';
import 'package:bb_mobile/core/ledger/data/repositories/ledger_device_repository_impl.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/connect_ledger_device_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/get_ledger_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/scan_ledger_devices_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/sign_psbt_ledger_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/verify_address_ledger_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/locator.dart';

class LedgerLocator {
  static void registerDatasources() {
    locator.registerLazySingleton<LedgerDeviceDatasource>(
      () => LedgerDeviceDatasource(),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<LedgerDeviceRepository>(
      () => LedgerDeviceRepositoryImpl(
        datasource: locator<LedgerDeviceDatasource>(),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<ScanLedgerDevicesUsecase>(
      () => ScanLedgerDevicesUsecase(
        repository: locator<LedgerDeviceRepository>(),
      ),
    );
    locator.registerFactory<ConnectLedgerDeviceUsecase>(
      () => ConnectLedgerDeviceUsecase(
        repository: locator<LedgerDeviceRepository>(),
      ),
    );
    locator.registerFactory<GetLedgerWatchOnlyWalletUsecase>(
      () => GetLedgerWatchOnlyWalletUsecase(
        repository: locator<LedgerDeviceRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SignPsbtLedgerUsecase>(
      () =>
          SignPsbtLedgerUsecase(repository: locator<LedgerDeviceRepository>()),
    );
    locator.registerFactory<VerifyAddressLedgerUsecase>(
      () => VerifyAddressLedgerUsecase(
        repository: locator<LedgerDeviceRepository>(),
      ),
    );
  }
}
