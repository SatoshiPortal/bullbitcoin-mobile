import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/electrum_settings/data/environment_adapter.dart';
import 'package:bull_tor/tor.dart';
import 'package:electrum/electrum.dart';
import 'package:sync/sync.dart' show WalletConnectionPort;

WalletConnectionPort createBackgroundWalletConnections(
  SqliteDatabase sqlite,
  SettingsRepository settings,
  Tor tor,
) => createWalletConnections(
  sqlite,
  readPreferences: EnvironmentAdapter(settingsRepository: () => settings)
      .readPreferences,
  tor: tor,
);
