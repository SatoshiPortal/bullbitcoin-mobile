import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:drift/drift.dart';

class Schema6To7 {
  static Future<void> migrate(Migrator m, Schema7 schema7) async {
    final defaultServerUrls = [
      ApiServiceConstants.bbElectrumUrl,
      ApiServiceConstants.bbLiquidElectrumUrlPath,
      ApiServiceConstants.publicElectrumUrl,
      ApiServiceConstants.publicLiquidElectrumUrlPath,
      ApiServiceConstants.publicElectrumTestUrl,
      ApiServiceConstants.publicliquidElectrumTestUrlPath,
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
