import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart';

class UpdateTorTransportModeUsecase {
  final SettingsRepository _settingsRepository;
  final EmbeddedTor _embeddedTor;

  UpdateTorTransportModeUsecase(this._settingsRepository, this._embeddedTor);

  Future<TorConnectionState> execute(TorTransportMode mode) async {
    // The mode is applied regardless: failing to remember the preference is
    // less bad than not honouring the switch the user just flipped. The raw
    // reason was logged at the repository boundary.
    if (await _settingsRepository.setTorTransportMode(mode) case Err(
      :final failure,
    )) {
      log.warning(
        'Could not persist the Tor transport mode: ${failure.runtimeType}',
      );
    }

    return _embeddedTor.setMode(mode);
  }
}
