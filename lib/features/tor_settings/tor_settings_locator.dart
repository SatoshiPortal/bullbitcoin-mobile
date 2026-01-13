import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/update_tor_settings_usecase.dart';
import 'package:bb_mobile/core/tor/domain/usecases/check_tor_proxy_connection_usecase.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:get_it/get_it.dart';

class TorSettingsLocator {
  static void setup(GetIt locator) {
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
