import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:tor/tor.dart';

class UpdateTorTransportModeUsecase {
  final SettingsRepository _settingsRepository;
  final EmbeddedTor _embeddedTor;

  UpdateTorTransportModeUsecase(this._settingsRepository, this._embeddedTor);

  Future<TorConnectionState> execute(TorTransportMode mode) async {
    await _settingsRepository.setTorTransportMode(mode);
    return _embeddedTor.setMode(mode);
  }
}
