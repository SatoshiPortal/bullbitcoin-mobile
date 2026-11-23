import 'package:bb_mobile/core/storage/migrations/migration_guards.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:electrum/setup.dart' show ElectrumDefaultEndpoints;
import 'package:drift/drift.dart';

class Schema6To7 {
  static Future<void> migrate(Migrator m, Schema7 schema7) async {
    // This step ends by removing is_custom's DEFAULT, and no later step adds
    // one back. Once it has run, a second run would mark later default servers
    // (fulcrum, 10→11) custom and rebuild electrum_servers in the v7 shape.
    if (await m.columnDefault('electrum_servers', 'is_custom') == null) return;

    final defaultServerUrls = [
      ElectrumDefaultEndpoints.bbElectrumUrl,
      ElectrumDefaultEndpoints.bbLiquidElectrumUrlPath,
      ElectrumDefaultEndpoints.publicElectrumUrl,
      ElectrumDefaultEndpoints.publicLiquidElectrumUrlPath,
      ElectrumDefaultEndpoints.publicElectrumTestUrl,
      ElectrumDefaultEndpoints.publicliquidElectrumTestUrlPath,
    ];

    // All entries that are not in the list above should have isCustom = true
    //  This fix is needed because in the previous migration isCustom was added
    //  with a default value of false, and we didn't take already existing custom
    //  servers into account.
    await m.database.customUpdate(
      'UPDATE electrum_servers SET is_custom = 1 WHERE url NOT IN (${defaultServerUrls.map((_) => '?').join(', ')})',
      variables: defaultServerUrls.map((url) => Variable<String>(url)).toList(),
      updates: {schema7.electrumServers},
    );

    // Recreate the table to remove the DEFAULT constraint from is_custom
    await m.alterTable(
      // ignore: experimental_member_use
      TableMigration(
        schema7.electrumServers,
        // map every column to itself to copy data during rebuild
        columnTransformer: {
          schema7.electrumServers.url: schema7.electrumServers.url,
          schema7.electrumServers.isTestnet: schema7.electrumServers.isTestnet,
          schema7.electrumServers.isLiquid: schema7.electrumServers.isLiquid,
          schema7.electrumServers.priority: schema7.electrumServers.priority,
          schema7.electrumServers.isCustom: schema7.electrumServers.isCustom,
        },
      ),
    );
  }
}
