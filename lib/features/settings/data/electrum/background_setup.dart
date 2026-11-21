import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/settings/data/electrum/environment_adapter.dart';
import 'package:bull_tor/tor.dart';
import 'package:electrum/electrum.dart';
import 'package:electrum/setup.dart';
import 'package:sync/sync.dart' show WalletConnectionPort;

WalletConnectionPort createBackgroundWalletConnections(
  SqliteDatabase sqlite,
  SettingsRepository settings,
  Tor tor,
) {
  final preferences = EnvironmentAdapter(settingsRepository: () => settings);
  return Electrum.open(
    database: sqlite,
    readNetwork: preferences.readNetwork,
    readPreferences: preferences.readPreferences,
    tor: () => tor,
  ).walletConnections;
}
