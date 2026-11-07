import 'package:bb_mobile/core/electrum/adapters/drift_electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/adapters/drift_electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/adapters/electrum_servers_adapter.dart';
import 'package:bb_mobile/core/electrum/adapters/electrum_tor_session_adapter.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/electrum_settings/data/wallet_connection_policy_impl.dart';
import 'package:bull_tor/tor.dart';
import 'package:transaction_sync/transaction_sync.dart';

WalletConnectionPolicy createBackgroundWalletConnections(
  SqliteDatabase sqlite,
  SettingsRepository settings,
  Tor tor,
) {
  return WalletConnectionPolicyImpl(
    ElectrumServersAdapter(
      serverRepository: DriftElectrumServerRepository(
        electrumServerStorageDatasource: ElectrumServerStorageDatasource(
          sqlite: sqlite,
        ),
      ),
      settingsRepository: DriftElectrumSettingsRepository(
        electrumSettingsStorageDatasource: ElectrumSettingsStorageDatasource(
          sqlite: sqlite,
        ),
      ),
      appSettingsRepository: settings,
      torSessionPort: ElectrumTorSessionAdapter(() => tor),
    ),
  );
}
