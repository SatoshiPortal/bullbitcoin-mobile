import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/tor_settings/domain/ports/socket_port.dart';
import 'package:bb_mobile/features/tor_settings/domain/usecases/check_tor_proxy_connection_usecase.dart';
import 'package:bb_mobile/features/tor_settings/infrastructure/adapters/socket_adapter.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';

class TorSettingsDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {
    sl.registerLazySingleton<SocketPort>(() => SocketAdapter());
  }

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerLazySingleton<CheckTorProxyConnectionUsecase>(
      () => CheckTorProxyConnectionUsecase(socketPort: sl()),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactory<TorSettingsCubit>(
      () => TorSettingsCubit(
        getSettingsUsecase: sl(),
        updateTorSettingsUsecase: sl(),
        checkTorConnectionUsecase: sl(),
      ),
    );
  }
}
