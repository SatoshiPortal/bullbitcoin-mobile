import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_account_selection_port.dart';
import '../ark_failure.dart';
import '../repositories/ark_preferences_repository.dart';

final class ArkSettings {
  final ArkAccountConfig config;
  final bool enabled;
  const ArkSettings(this.config, this.enabled);
}

final class LoadArkSettingsUsecase {
  final ArkAccountSelectionPort _selection;
  final ArkPreferencesRepository _preferences;
  const LoadArkSettingsUsecase(this._selection, this._preferences);
  Future<Result<ArkSettings, ArkFailure>> execute() async {
    switch (await _selection.selectedAccount()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return (await _preferences.isEnabled(value.id))
            .map((enabled) => ArkSettings(value, enabled));
    }
  }
}
