import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart';

class UpdateTorTransportModeUsecase {
  final Preferences _preferences;
  final EmbeddedTor _embeddedTor;

  UpdateTorTransportModeUsecase(this._preferences, this._embeddedTor);

  Future<TorConnectionState> execute(TorTransportMode mode) async {
    // The mode is applied regardless: failing to remember the preference is
    // less bad than not honouring the switch the user just flipped. The raw
    // reason was logged at the repository boundary.
    if (await _preferences.setTorTransportMode(mode) case Err(:final failure)) {
      log.warning(
        'Could not persist the Tor transport mode: ${failure.runtimeType}',
      );
    }

    return _embeddedTor.setMode(mode);
  }
}
