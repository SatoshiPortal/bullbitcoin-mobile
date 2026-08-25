import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/tor_settings/domain/check_external_tor_connection_usecase.dart';
import 'package:bb_mobile/features/tor_settings/domain/update_tor_proxy_usecase.dart';
import 'package:bb_mobile/features/tor_settings/domain/update_tor_transport_mode_usecase.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/embedded_tor_status_cubit.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_tor/tor.dart';

class TorSettingsLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<UpdateTorTransportModeUsecase>(
      () => UpdateTorTransportModeUsecase(
        locator<SettingsRepository>(),
        locator<Tor>().embedded,
      ),
    );
    locator.registerLazySingleton<UpdateTorProxyUsecase>(
      () => UpdateTorProxyUsecase(
        locator<SettingsRepository>(),
        locator<VerifyExternalTorUsecase>(),
      ),
    );
    locator.registerFactory<CheckExternalTorConnectionUsecase>(
      () => CheckExternalTorConnectionUsecase(
        locator<GetSettingsUsecase>(),
        locator<Tor>(),
      ),
    );

    // Presentation
    locator.registerFactory<EmbeddedTorStatusCubit>(
      () => EmbeddedTorStatusCubit(
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        watchTorConnectionUsecase: locator<WatchTorConnectionUsecase>(),
        retryTorConnectionUsecase: locator<RetryTorConnectionUsecase>(),
      ),
    );
    locator.registerFactory<TorSettingsCubit>(
      () => TorSettingsCubit(
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        updateTorProxyUsecase: locator<UpdateTorProxyUsecase>(),
        updateTorTransportModeUsecase: locator<UpdateTorTransportModeUsecase>(),
        watchTorConnectionUsecase: locator<WatchTorConnectionUsecase>(),
        checkExternalTorConnectionUsecase:
            locator<CheckExternalTorConnectionUsecase>(),
      ),
    );
  }
}
