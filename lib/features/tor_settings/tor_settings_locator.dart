import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/locator.dart';

class TorSettingsLocator {
  static void setup() {
    locator.registerFactory<TorSettingsCubit>(
      () => TorSettingsCubit(
        electrumSettingsRepository: locator<ElectrumSettingsRepository>(),
      ),
    );
  }
}
