import 'package:bb_mobile/core/ledger/data/datasources/ledger_device_datasource.dart';
import 'package:bb_mobile/core/ledger/data/repositories/ledger_device_repository_impl.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/connect_ledger_device_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/get_ledger_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/scan_ledger_devices_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/sign_psbt_ledger_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/verify_address_ledger_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';

class Ledgersl {
  static void registerDatasources() {
    sl.registerLazySingleton<LedgerDeviceDatasource>(
      () => LedgerDeviceDatasource(),
    );
  }

  static void registerRepositories() {
    sl.registerLazySingleton<LedgerDeviceRepository>(
      () =>
          LedgerDeviceRepositoryImpl(datasource: sl<LedgerDeviceDatasource>()),
    );
  }

  static void registerUsecases() {
    sl.registerFactory<ScanLedgerDevicesUsecase>(
      () => ScanLedgerDevicesUsecase(repository: sl<LedgerDeviceRepository>()),
    );
    sl.registerFactory<ConnectLedgerDeviceUsecase>(
      () =>
          ConnectLedgerDeviceUsecase(repository: sl<LedgerDeviceRepository>()),
    );
    sl.registerFactory<GetLedgerWatchOnlyWalletUsecase>(
      () => GetLedgerWatchOnlyWalletUsecase(
        repository: sl<LedgerDeviceRepository>(),
        settingsRepository: sl<SettingsRepository>(),
      ),
    );
    sl.registerFactory<SignPsbtLedgerUsecase>(
      () => SignPsbtLedgerUsecase(repository: sl<LedgerDeviceRepository>()),
    );
    sl.registerFactory<VerifyAddressLedgerUsecase>(
      () =>
          VerifyAddressLedgerUsecase(repository: sl<LedgerDeviceRepository>()),
    );
  }
}
