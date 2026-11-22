import 'package:bull_tor/tor.dart';
import 'package:get_it/get_it.dart';
import 'package:preferences/preferences.dart';

import 'domain/check_external_tor_connection_usecase.dart';
import 'domain/load_tor_preferences_usecase.dart';
import 'domain/update_tor_proxy_usecase.dart';
import 'domain/update_tor_transport_mode_usecase.dart';
import 'domain/watch_tor_settings_usecase.dart';
import 'presentation/tor_settings_cubit.dart';

void setupTorSettings(GetIt locator, Preferences preferences) {
  locator.registerLazySingleton<UpdateTorProxyUsecase>(
    () => UpdateTorProxyUsecase(preferences, locator<Tor>().external),
  );
  locator.registerFactory<TorSettingsCubit>(() {
    final tor = locator<Tor>();
    return TorSettingsCubit(
      loadPreferences: LoadTorPreferencesUsecase(preferences),
      updateTorProxyUsecase: locator<UpdateTorProxyUsecase>(),
      updateTorTransportModeUsecase: UpdateTorTransportModeUsecase(
        preferences,
        tor.embedded,
      ),
      watchSettingsUsecase: WatchTorSettingsUsecase(tor.embedded),
      checkExternalTorConnectionUsecase: CheckExternalTorConnectionUsecase(
        preferences,
        tor,
      ),
    );
  });
}
