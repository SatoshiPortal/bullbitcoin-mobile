import 'package:electrum/setup.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_active_network_usecase.dart';

class SetEnvironmentUsecase {
  final Preferences _settingsRepository;
  final ElectrumDefaultsProvisioner _electrumSettings;

  const SetEnvironmentUsecase({
    required this._settingsRepository,
    required this._electrumSettings,
  });

  @useResult
  Future<Result<void, SettingsFailure>> execute(Environment environment) async {
    return SetActiveNetworkUsecase(
      settingsRepository: _settingsRepository,
      electrumSettings: _electrumSettings,
    ).execute(environment.networkEnv);
  }
}
