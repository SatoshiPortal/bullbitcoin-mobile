import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../../status_check/domain/network_failure.dart';
import 'tor_preferences.dart';

class LoadTorPreferencesUsecase {
  final Preferences _preferences;

  const LoadTorPreferencesUsecase(this._preferences);

  Future<Result<TorPreferences, NetworkFailure>> execute() async =>
      (await _preferences.fetch())
          .map(
            (settings) => (
              useTorProxy: settings.useTorProxy,
              torProxyPort: settings.torProxyPort,
              torTransportMode: settings.torTransportMode,
              lastSuccessfulTorTransport: settings.lastSuccessfulTorTransport,
            ),
          )
          .mapErr((_) => const NetworkUnexpectedFailure());
}
