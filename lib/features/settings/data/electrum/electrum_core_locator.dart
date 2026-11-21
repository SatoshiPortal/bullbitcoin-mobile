import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/settings/data/electrum/environment_adapter.dart';
import 'package:bull_tor/tor.dart' show Tor;
import 'package:electrum/electrum.dart';
import 'package:electrum/setup.dart';
import 'package:get_it/get_it.dart';
import 'package:sync/sync.dart' show WalletConnectionPort;

void setupElectrum(GetIt locator) {
  final environment = EnvironmentAdapter(
    settingsRepository: () => locator<Preferences>(),
  );
  locator.registerLazySingleton<Electrum>(
    () => Electrum.open(
      database: locator<SqliteDatabase>(),
      readPreferences: environment.readPreferences,
      tor: () => locator<Tor>(),
    ),
  );
  locator.registerLazySingleton<WalletConnectionPort>(
    () => locator<Electrum>().walletConnections,
  );
  locator.registerLazySingleton<ElectrumServersPort>(
    () => locator<Electrum>().integrationRunner,
  );
  locator.registerLazySingleton<ElectrumDefaultsProvisioner>(
    () => locator<Electrum>().foregroundStorage,
  );
}
