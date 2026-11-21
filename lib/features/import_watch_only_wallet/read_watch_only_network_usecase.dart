import 'package:preferences/preferences.dart' show ActiveEnvironmentReader;
import 'package:primitives/primitives.dart' show NetworkEnv;

class ReadWatchOnlyNetworkUsecase {
  final ActiveEnvironmentReader _preferences;

  const ReadWatchOnlyNetworkUsecase(this._preferences);

  Future<NetworkEnv> execute() async =>
      (await _preferences.readActiveEnvironment()).networkEnv;
}
