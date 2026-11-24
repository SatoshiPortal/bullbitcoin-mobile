import 'package:preferences/preferences.dart';
import 'package:settings/src/data/recoverbull_settings_adapter.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:meta/meta.dart' show visibleForTesting;
import 'package:primitives/primitives.dart' show RegtestHostProfile;

import '../domain/regtest_recoverbull_profile.dart';

final class SettingsRecoverBullBindings {
  static Future<({String path, Uri server})> setup(
    GetIt locator, {
    required String databasePath,
    @visibleForTesting String? regtestHost,
  }) async {
    final settings = (await locator<Preferences>().fetch()).fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    );
    final network = settings.environment.networkEnv;
    final host = regtestHost == null
        ? RegtestHostProfile.forNetwork(network)
        : RegtestHostProfile.forNetwork(network, host: regtestHost);
    final adapter = RecoverBullSettingsAdapter(
      locator<Preferences>(),
      locator<RecoverBullPreferences>(),
      locator<Tor>().embedded,
      locator<Tor>(),
      regtestProfile: host == null ? null : RegtestRecoverBullProfile(host),
    );
    locator.registerSingleton<RecoverBullRoutePort>(
      adapter,
      dispose: (_) => adapter.close(),
    );
    locator.registerSingleton<RecoverBullEnvironmentPort>(adapter);
    locator.registerSingleton<RecoverBullPermissionPort>(adapter);
    return (
      path: host == null
          ? databasePath
          : p.join(p.dirname(databasePath), 'recoverbull-regtest.sqlite'),
      server: adapter.configuredServer,
    );
  }
}
