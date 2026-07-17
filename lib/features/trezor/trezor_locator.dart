import 'package:bb_mobile/features/trezor/data/trezor_callback_port_impl.dart';
import 'package:bb_mobile/features/trezor/data/trezor_connect_datasource.dart';
import 'package:bb_mobile/features/trezor/data/trezor_device_repository_impl.dart';
import 'package:bb_mobile/features/trezor/domain/repositories/trezor_device_repository.dart';
import 'package:bb_mobile/features/trezor/domain/trezor_callback_port.dart';
import 'package:bb_mobile/features/trezor/domain/usecases/get_default_trezor_account_usecase.dart';
import 'package:bb_mobile/features/trezor/domain/usecases/prepare_trezor_import_usecase.dart';
import 'package:bb_mobile/features/trezor/domain/usecases/sign_psbt_trezor_usecase.dart';
import 'package:bb_mobile/features/trezor/domain/usecases/verify_address_trezor_usecase.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_import_cubit.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_sign_transaction_cubit.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_verify_address_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:trezor_connect/trezor_connect.dart';

class TrezorLocator {
  static void setup(GetIt locator) {
    _registerDatasources(locator);
    _registerRepositories(locator);
    _registerPorts(locator);
    _registerUsecases(locator);
    _registerCubits(locator);
  }

  static void _registerDatasources(GetIt locator) {
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

  static void _registerRepositories(GetIt locator) {
    locator.registerLazySingleton<TrezorDeviceRepository>(
      () => TrezorDeviceRepositoryImpl(
        datasource: locator<TrezorConnectDatasource>(),
      ),
    );
  }

  static void _registerPorts(GetIt locator) {
    locator.registerLazySingleton<TrezorCallbackPort>(
      () => TrezorCallbackPortImpl(
        datasource: locator<TrezorConnectDatasource>(),
      ),
    );
  }

  static void _registerUsecases(GetIt locator) {
    locator.registerFactory<GetDefaultTrezorAccountUsecase>(
      () => GetDefaultTrezorAccountUsecase(
        repository: locator<TrezorDeviceRepository>(),
      ),
    );
    locator.registerFactory<PrepareTrezorImportUsecase>(
      () => const PrepareTrezorImportUsecase(),
    );
    locator.registerFactory<VerifyAddressTrezorUsecase>(
      () => VerifyAddressTrezorUsecase(
        repository: locator<TrezorDeviceRepository>(),
      ),
    );
    locator.registerFactory<SignPsbtTrezorUsecase>(
      () =>
          SignPsbtTrezorUsecase(repository: locator<TrezorDeviceRepository>()),
    );
  }

  static void _registerCubits(GetIt locator) {
    locator.registerFactory<TrezorImportCubit>(
      () => TrezorImportCubit(
        getDefaultAccount: locator<GetDefaultTrezorAccountUsecase>(),
        prepareImport: locator<PrepareTrezorImportUsecase>(),
      ),
    );
    locator.registerFactory<TrezorVerifyAddressCubit>(
      () => TrezorVerifyAddressCubit(
        verifyAddress: locator<VerifyAddressTrezorUsecase>(),
      ),
    );
    locator.registerFactory<TrezorSignTransactionCubit>(
      () => TrezorSignTransactionCubit(
        signPsbt: locator<SignPsbtTrezorUsecase>(),
      ),
    );
  }
}
