import 'package:bull_tor/tor.dart';
import 'package:get_it/get_it.dart';
import 'package:primitives/primitives.dart';

import 'domain/check_external_tor_connection_usecase.dart';
import 'domain/tor_preferences.dart';
import 'domain/update_tor_proxy_usecase.dart';
import 'domain/update_tor_transport_mode_usecase.dart';
import 'domain/watch_tor_settings_usecase.dart';
import 'presentation/tor_settings_cubit.dart';

class TorSettingsLocator {
  static void setup(
    GetIt locator, {
    required ReadTorPreferences readPreferences,
    required SaveTorProxy saveProxy,
    required Future<Result<void, Failure>> Function(TorTransportMode) saveMode,
  }) {
    locator.registerLazySingleton<UpdateTorProxyUsecase>(
      () => UpdateTorProxyUsecase(saveProxy, locator<Tor>().external),
    );
    locator.registerFactory<TorSettingsCubit>(() {
      final tor = locator<Tor>();
      return TorSettingsCubit(
        readPreferences: readPreferences,
        updateTorProxyUsecase: locator<UpdateTorProxyUsecase>(),
        updateTorTransportModeUsecase: UpdateTorTransportModeUsecase(
          saveMode,
          tor.embedded,
        ),
        watchSettingsUsecase: WatchTorSettingsUsecase(tor.embedded),
        checkExternalTorConnectionUsecase: CheckExternalTorConnectionUsecase(
          readPreferences,
          tor,
        ),
      );
    });
  }
}
