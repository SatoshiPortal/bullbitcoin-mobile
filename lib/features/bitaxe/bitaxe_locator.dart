import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'application/ports/bitaxe_local_storage_port.dart';
import 'application/ports/bitaxe_remote_datasource_port.dart';
import 'application/usecases/connect_to_device_usecase.dart';
import 'application/usecases/get_stored_connection_usecase.dart';
import 'application/usecases/get_system_info_usecase.dart';
import 'application/usecases/identify_device_usecase.dart';
import 'application/usecases/remove_connection_usecase.dart';
import 'frameworks/http/bitaxe_api_client.dart';
import 'frameworks/storage/bitaxe_local_storage.dart';
import 'interface_adapters/repositories/bitaxe_remote_datasource_impl.dart';
import 'presentation/bloc/bitaxe_bloc.dart';

class BitaxeLocator {
  static void setup(GetIt locator) {
    registerFrameworks(locator);
    registerInterfaceAdapters(locator);
    registerUsecases(locator);
    registerPresentation(locator);
  }

  static void registerFrameworks(GetIt locator) {
    // HTTP Client for Bitaxe API
    // Note: No fixed baseUrl since each device has a different IP address
    // We build the full URL in each request using the device's IP
    locator.registerFactory<BitaxeApiClient>(
      () => BitaxeApiClient(
        dio: Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        ),
      ),
    );

    // Local Storage
    locator.registerLazySingleton<BitaxeLocalStorage>(
      () => BitaxeLocalStorage(
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );
  }

  static void registerInterfaceAdapters(GetIt locator) {
    // Remote Data Source
    locator.registerLazySingleton<BitaxeRemoteDatasourcePort>(
      () => BitaxeRemoteDatasourceImpl(apiClient: locator<BitaxeApiClient>()),
    );

    // Local Storage Port
    // BitaxeLocalStorage implements BitaxeLocalStoragePort directly
    locator.registerLazySingleton<BitaxeLocalStoragePort>(
      () => locator<BitaxeLocalStorage>(),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<ConnectToDeviceUsecase>(
      () => ConnectToDeviceUsecase(
        remoteDatasource: locator<BitaxeRemoteDatasourcePort>(),
        localStorage: locator<BitaxeLocalStoragePort>(),
        getReceiveAddressUsecase: locator<GetReceiveAddressUsecase>(),
      ),
    );

    locator.registerFactory<GetSystemInfoUsecase>(
      () => GetSystemInfoUsecase(
        remoteDatasource: locator<BitaxeRemoteDatasourcePort>(),
      ),
    );

    locator.registerFactory<IdentifyDeviceUsecase>(
      () => IdentifyDeviceUsecase(
        remoteDatasource: locator<BitaxeRemoteDatasourcePort>(),
      ),
    );

    locator.registerFactory<GetStoredConnectionUsecase>(
      () => GetStoredConnectionUsecase(
        localStorage: locator<BitaxeLocalStoragePort>(),
        remoteDatasource: locator<BitaxeRemoteDatasourcePort>(),
      ),
    );

    locator.registerFactory<RemoveConnectionUsecase>(
      () => RemoveConnectionUsecase(
        localStorage: locator<BitaxeLocalStoragePort>(),
      ),
    );
  }

  static void registerPresentation(GetIt locator) {
    locator.registerFactory<BitaxeBloc>(
      () => BitaxeBloc(
        connectToDeviceUsecase: locator<ConnectToDeviceUsecase>(),
        getSystemInfoUsecase: locator<GetSystemInfoUsecase>(),
        identifyDeviceUsecase: locator<IdentifyDeviceUsecase>(),
        getStoredConnectionUsecase: locator<GetStoredConnectionUsecase>(),
        removeConnectionUsecase: locator<RemoveConnectionUsecase>(),
      ),
    );
  }
}
