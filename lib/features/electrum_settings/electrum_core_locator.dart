import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/electrum_settings/data/environment_adapter.dart';
import 'package:bull_tor/tor.dart' show Tor;
import 'package:electrum/electrum.dart';
import 'package:get_it/get_it.dart';

void setupElectrum(GetIt locator) {
  final environment = EnvironmentAdapter(
    settingsRepository: () => locator<SettingsRepository>(),
  );
  ElectrumLocator.registerDatasources(locator, () => locator<SqliteDatabase>());
  ElectrumLocator.registerRepositories(locator);
  ElectrumLocator.registerPorts(
    locator,
    environment: environment,
    readPreferences: environment.readPreferences,
    tor: () => locator<Tor>(),
  );
  ElectrumLocator.registerUsecases(locator, environment.readPreferences);
}
