import 'package:bull_tor/tor.dart' show Tor;
import 'package:drift/drift.dart' show GeneratedDatabase;
import 'package:sync/sync.dart' show WalletConnectionPort;

import 'data/drift_electrum_server_repository.dart';
import 'data/drift_electrum_settings_repository.dart';
import 'data/electrum_server_storage_datasource.dart';
import 'data/electrum_servers_adapter.dart';
import 'data/electrum_settings_storage_datasource.dart';
import 'data/electrum_tor_session_adapter.dart';
import 'data/wallet_connection_policy_impl.dart';
import 'domain/electrum_preferences.dart';

WalletConnectionPort createWalletConnections(
  GeneratedDatabase database, {
  required Future<ElectrumPreferences> Function() readPreferences,
  required Tor tor,
}) => WalletConnectionPolicyImpl(
  ElectrumServersAdapter(
    serverRepository: DriftElectrumServerRepository(
      electrumServerStorageDatasource: ElectrumServerStorageDatasource(
        sqlite: database,
      ),
    ),
    settingsRepository: DriftElectrumSettingsRepository(
      electrumSettingsStorageDatasource: ElectrumSettingsStorageDatasource(
        sqlite: database,
      ),
    ),
    readPreferences: readPreferences,
    torSessionPort: ElectrumTorSessionAdapter(() => tor),
  ),
);
