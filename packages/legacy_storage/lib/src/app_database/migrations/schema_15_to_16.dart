import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';

import 'migration_guards.dart';
import '../sqlite_database.steps.dart';

/// The single pending revision: concrete wallet/Electrum networks, removal
/// of the price cache now owned by bull_pricer, and the move of the default
/// Blockstream Electrum servers off ports 700, 993, 995 and 465 (filtered by
/// many networks) to Blockstream's current hosts on 50002.
class Schema15To16 {
  static Future<void> migrate(Migrator m, Schema16 schema16) =>
      m.database.transaction(() => _migrate(m, schema16));

  // Keep the backfill and table replacement atomic even when migration tools
  // invoke this step directly, without SqliteDatabase's reporting wrapper.
  static Future<void> _migrate(Migrator m, Schema16 schema16) async {
    if (!await m.hasColumn('settings', 'start_amounts_in_fiat')) {
      await m.database.customStatement(
        'ALTER TABLE settings ADD COLUMN start_amounts_in_fiat INTEGER NOT NULL DEFAULT 0 CHECK (start_amounts_in_fiat IN (0, 1))',
      );
    }
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
        final network = _legacyWalletNetwork(id);
        if (network == null) {
          // Preserve the row for repair; an unresolved network fails closed.
          unresolved++;
          continue;
        }
        await m.database.customStatement(
          'UPDATE wallet_metadatas SET network = ? WHERE id = ?',
          [network, id],
        );
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
    // Only default rows change: a custom server is never touched, and once a
    // row holds the new URL the update matches nothing, so a rerun is a
    // no-op. Runs after the network rebuild, which keeps url and is_custom.
    // The URLs are literals, not constants, so this step never changes with
    // them.
    for (final (from, to) in [
      (
        'ssl://blockstream.info:700',
        'ssl://bitcoin-mainnet.blockstream.info:50002',
      ),
      ('blockstream.info:995', 'elements-mainnet.blockstream.info:50002'),
      (
        'ssl://blockstream.info:993',
        'ssl://bitcoin-testnet.blockstream.info:50002',
      ),
      ('blockstream.info:465', 'elements-testnet.blockstream.info:50002'),
    ]) {
      await m.database.customUpdate(
        'UPDATE OR IGNORE electrum_servers SET url = ? WHERE url = ? AND is_custom = 0',
        variables: [Variable<String>(to), Variable<String>(from)],
        updates: {schema16.electrumServers},
      );
    }
    // The cache is now owned by bull_pricer. Safe on every rerun.
    await m.deleteTable('prices');
  }

  /// v15 origin syntax and network names are part of the migration.
  static String? _legacyWalletNetwork(String origin) {
    final match = RegExp(r'\[([a-fA-F0-9]+)/(\d+h)/(\d+h)/(\d+h)\]')
        .firstMatch(origin);
    if (match?.group(2) case '44h' || '49h' || '84h') {
      return switch (match?.group(3)) {
        '0h' => 'bitcoinMainnet',
        '1h' =>
          origin.contains('elwpkh(') ||
                  origin.contains('elsh(wpkh(') ||
                  origin.contains('elpkh(')
              ? 'liquidTestnet'
              : 'bitcoinTestnet',
        '1776h' => 'liquidMainnet',
        _ => null,
      };
    }
    return null;
  }
}
