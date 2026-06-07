import 'package:bb_mobile/features/trezor/adapters/trezor_callback_dispatcher_impl.dart';
import 'package:bb_mobile/features/trezor/adapters/trezor_device_repository_impl.dart';
import 'package:bb_mobile/features/trezor/application/trezor_callback_dispatcher.dart';
import 'package:bb_mobile/features/trezor/application/trezor_device_repository.dart';
import 'package:bb_mobile/features/trezor/application/usecases/get_default_trezor_account_usecase.dart';
import 'package:bb_mobile/features/trezor/application/usecases/prepare_trezor_import_usecase.dart';
import 'package:bb_mobile/features/trezor/application/usecases/sign_psbt_trezor_usecase.dart';
import 'package:bb_mobile/features/trezor/application/usecases/verify_address_trezor_usecase.dart';
import 'package:bb_mobile/features/trezor/frameworks/trezor_connect_datasource.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_import_cubit.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_sign_transaction_cubit.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_verify_address_cubit.dart';
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
    locator.registerLazySingleton<TrezorCallbackDispatcher>(
      () => TrezorCallbackDispatcherImpl(
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

  static void _registerFacade(GetIt locator) {
    locator.registerLazySingleton<TrezorFacade>(
      () => TrezorFacade(
        prepareTrezorImportUsecase: locator<PrepareTrezorImportUsecase>(),
      ),
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
