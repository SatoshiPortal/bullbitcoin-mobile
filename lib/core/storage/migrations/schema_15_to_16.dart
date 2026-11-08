import 'package:bb_mobile/core/storage/migrations/migration_guards.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
import 'package:bb_mobile/features/wallet/data/wallet_network_codec.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';

/// The single pending revision: concrete wallet/Electrum networks and removal
/// of the price cache now owned by bull_pricer.
class Schema15To16 {
  static Future<void> migrate(Migrator m, Schema16 schema16) =>
      m.database.transaction(() => _migrate(m, schema16));

  // Keep the backfill and table replacement atomic even when migration tools
  // invoke this step directly, without SqliteDatabase's reporting wrapper.
  static Future<void> _migrate(Migrator m, Schema16 schema16) async {
    if (!await m.hasColumn('wallet_metadatas', 'network')) {
      await m.addColumn(
        schema16.walletMetadatas,
        schema16.walletMetadatas.network,
      );
      final rows = await m.database
          .customSelect('SELECT id FROM wallet_metadatas')
          .get();
      var unresolved = 0;
      for (final row in rows) {
        final id = row.read<String>('id');
        try {
          // Historical origins encode only the four shipped networks. Never
          // run this backfill again once a concrete network has been stored.
          final origin = WalletMetadataService.decodeOrigin(origin: id);
          await m.database.customStatement(
            'UPDATE wallet_metadatas SET network = ? WHERE id = ?',
            [WalletNetworkCodec.encode(origin.network), id],
          );
        } on String {
          // Preserve the row for repair; an unresolved network fails closed.
          unresolved++;
        }
      }
      if (unresolved > 0) {
        log.warning('Wallet network backfill unresolved_count=$unresolved');
      }
    }
    if (!await m.hasColumn('electrum_servers', 'network')) {
      // The migration transaction owns the rebuild. The final column
      // is the rerun guard, so neither user edits nor priorities are reset.
      await m.database.customStatement('''
        CREATE TABLE electrum_servers_network (
          url TEXT NOT NULL,
          network TEXT NOT NULL,
          priority INTEGER NOT NULL,
          is_custom INTEGER NOT NULL CHECK (is_custom IN (0, 1)),
          PRIMARY KEY (network, url)
        )
      ''');
      await m.database.customStatement('''
        INSERT INTO electrum_servers_network (url, network, priority, is_custom)
        SELECT url, CASE
          WHEN is_liquid = 1 AND is_testnet = 1 THEN 'liquidTestnet'
          WHEN is_liquid = 1 THEN 'liquidMainnet'
          WHEN is_testnet = 1 THEN 'bitcoinTestnet'
          ELSE 'bitcoinMainnet'
        END, priority, is_custom FROM electrum_servers
      ''');
      await m.database.customStatement('DROP TABLE electrum_servers');
      await m.database.customStatement(
        'ALTER TABLE electrum_servers_network RENAME TO electrum_servers',
      );
      await m.database.customStatement(
        "INSERT INTO electrum_servers (url, network, priority, is_custom) VALUES ('tcp://127.0.0.1:50000', 'bitcoinRegtest', 0, 0)",
      );
      await m.database.customStatement(
        "INSERT OR IGNORE INTO electrum_settings (network, validate_domain, stop_gap, timeout, retry) VALUES ('bitcoinRegtest', 1, 20, 5, 5)",
      );
    }
    // The cache is now owned by bull_pricer. Safe on every rerun.
    await m.deleteTable('prices');
  }
}
