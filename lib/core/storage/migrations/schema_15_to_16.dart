import 'package:bb_mobile/core/storage/migrations/migration_guards.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Migration from version 15 to 16.
///
/// Adds the TLS certificate validation setting to Mempool servers.
///
/// Drops `prices`, the price history cache: the price history now lives in
/// the pricer's own database (`packages/bull_pricer`). The rows were only a
/// cache of the price service and are fetched again on the next opening of
/// the chart. `DROP TABLE IF EXISTS` makes a second run a no-op.
///
/// Moves the default Blockstream Electrum servers off ports 700, 993, 995
/// and 465 to Blockstream's current hosts on 50002; 700, 993 and 465 are
/// filtered by many networks. Only default rows
/// change: a custom server is never touched, and once a row holds the new
/// URL the update matches nothing, so a second run is a no-op. The URLs are
/// literals, not constants, so this step never changes with them.
class Schema15To16 {
  static Future<void> migrate(Migrator m, Schema16 schema16) async {
    await m.deleteTable('prices');
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
    await m.addColumnIfMissing(
      schema16.mempoolServers,
      schema16.mempoolServers.validateDomain,
    );
  }
}
