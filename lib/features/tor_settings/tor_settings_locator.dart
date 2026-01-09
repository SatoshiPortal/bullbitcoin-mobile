import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/update_tor_settings_usecase.dart';
import 'package:bb_mobile/features/tor_settings/domain/ports/socket_port.dart';
import 'package:bb_mobile/features/tor_settings/domain/usecases/check_tor_proxy_connection_usecase.dart';
import 'package:bb_mobile/features/tor_settings/infrastructure/adapters/socket_adapter.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:get_it/get_it.dart';

class TorSettingsLocator {
  static void setup(GetIt locator) {
    // Infrastructure
    locator.registerLazySingleton<SocketPort>(() => SocketAdapter());

    // Use cases
    locator.registerLazySingleton<CheckTorProxyConnectionUsecase>(
      () => CheckTorProxyConnectionUsecase(socketPort: locator<SocketPort>()),
    );

    // Presentation
    locator.registerFactory<TorSettingsCubit>(
      () => TorSettingsCubit(
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        updateTorSettingsUsecase: locator<UpdateTorSettingsUsecase>(),
        checkTorConnectionUsecase: locator<CheckTorProxyConnectionUsecase>(),
      ),
    );
  }
}
