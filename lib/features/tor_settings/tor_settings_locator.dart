import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/update_tor_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/tor_settings/domain/update_tor_transport_mode_usecase.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:tor/tor.dart';

class TorSettingsLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<UpdateTorTransportModeUsecase>(
      () => UpdateTorTransportModeUsecase(
        locator<SettingsRepository>(),
        locator<Tor>().embedded,
      ),
    );

    // Presentation
    locator.registerFactory<TorSettingsCubit>(
      () => TorSettingsCubit(
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        updateTorSettingsUsecase: locator<UpdateTorSettingsUsecase>(),
        updateTorTransportModeUsecase: locator<UpdateTorTransportModeUsecase>(),
        ensureTorReadyUsecase: locator<EnsureTorReadyUsecase>(),
        watchTorConnectionUsecase: locator<WatchTorConnectionUsecase>(),
        verifyExternalTorUsecase: locator<VerifyExternalTorUsecase>(),
      ),
    );
  }
}
