import 'package:bb_mobile/features/trezor/adapters/trezor_device_repository_impl.dart';
import 'package:bb_mobile/features/trezor/application/trezor_device_repository.dart';
import 'package:bb_mobile/features/trezor/application/usecases/get_trezor_accounts_usecase.dart';
import 'package:bb_mobile/features/trezor/application/usecases/prepare_trezor_import_usecase.dart';
import 'package:bb_mobile/features/trezor/application/usecases/verify_address_trezor_usecase.dart';
import 'package:bb_mobile/features/trezor/frameworks/trezor_connect_datasource.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_cubit.dart';
import 'package:bb_mobile/features/trezor/public/trezor_facade.dart';
import 'package:get_it/get_it.dart';
import 'package:trezor_connect/trezor_connect.dart';

class TrezorLocator {
  static void setup(GetIt locator) {
    _registerFrameworks(locator);
    _registerAdapters(locator);
    _registerUsecases(locator);
    _registerFacade(locator);
    _registerCubits(locator);
  }

  static void _registerFrameworks(GetIt locator) {
    locator.registerLazySingleton<TrezorConnect>(
      () => TrezorConnect(
        'bullbitcoin://trezor-callback',
        appName: 'Bull Bitcoin Wallet',
      ),
    );
    locator.registerLazySingleton<TrezorConnectDatasource>(
      () => TrezorConnectDatasource(connect: locator<TrezorConnect>()),
    );
  }

  static void _registerAdapters(GetIt locator) {
    locator.registerLazySingleton<TrezorDeviceRepository>(
      () => TrezorDeviceRepositoryImpl(
        datasource: locator<TrezorConnectDatasource>(),
      ),
    );
  }

  static void _registerUsecases(GetIt locator) {
    locator.registerFactory<GetTrezorAccountsUsecase>(
      () => GetTrezorAccountsUsecase(
        repository: locator<TrezorDeviceRepository>(),
      ),
    );
    locator.registerFactory<PrepareTrezorImportUsecase>(
      () => PrepareTrezorImportUsecase(
        trezorRepository: locator<TrezorDeviceRepository>(),
      ),
    );
    locator.registerFactory<VerifyAddressTrezorUsecase>(
      () => VerifyAddressTrezorUsecase(
        repository: locator<TrezorDeviceRepository>(),
      ),
    );
  }

  static void _registerFacade(GetIt locator) {
    locator.registerLazySingleton<TrezorFacade>(
      () => TrezorFacade(
        prepareTrezorImportUsecase: locator<PrepareTrezorImportUsecase>(),
        verifyAddressTrezorUsecase: locator<VerifyAddressTrezorUsecase>(),
      ),
    );
  }

  static void _registerCubits(GetIt locator) {
    locator.registerFactory<TrezorOperationCubit>(() => TrezorOperationCubit());
  }
}
