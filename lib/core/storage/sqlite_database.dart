import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/tables/electrum_servers_table.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/storage/tables/payjoin_receivers_table.dart';
import 'package:bb_mobile/core/storage/tables/payjoin_senders_table.dart';
import 'package:bb_mobile/core/storage/tables/settings_table.dart';
import 'package:bb_mobile/core/storage/tables/swaps_table.dart';
import 'package:bb_mobile/core/storage/tables/transactions_table.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/constants.dart';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:flutter/foundation.dart';

part 'sqlite_database.g.dart';

@DriftDatabase(
  tables: [
    Transactions,
    WalletMetadatas,
    Labels,
    Settings,
    PayjoinSenders,
    PayjoinReceivers,
    ElectrumServers,
    Swaps,
  ],
)
class SqliteDatabase extends _$SqliteDatabase {
  SqliteDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'bullbitcoin_sqlite',
      native: const DriftNativeOptions(),
    );
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Seed database with default values
        // !Important! If future migrations add columns that require default
        //  values as well, the seeding of that column has to be done in the
        //  migration step as well, since either the onCreate or the migration
        //  steps get executed, not both. Make sure in the migration you only
        //  seed the new columns and don't overwrite any existing data.
        await Future.wait([
          _seedDefaultSettings(),
          _seedDefaultElectrumServers(),
        ]);
      },
    );
  }

  Future<void> _seedDefaultSettings() async {
    debugPrint('[SqliteDatabase] seeding default settings...');
    await into(settings).insert(
      SettingsRow(
        id: 1,
        environment: Environment.mainnet.name,
        bitcoinUnit: BitcoinUnit.btc.name,
        language: Language.unitedStatesEnglish.name,
        currency: 'USD',
        hideAmounts: false,
      ),
    );
  }

  Future<void> _seedDefaultElectrumServers() async {
    final serversData = [
      (ApiServiceConstants.bbElectrumUrl, false, false, 1),
      (ApiServiceConstants.bbLiquidElectrumUrlPath, false, true, 1),
      (ApiServiceConstants.publicElectrumUrl, false, false, 2),
      (ApiServiceConstants.publicLiquidElectrumUrlPath, false, true, 2),
      (ApiServiceConstants.publicElectrumTestUrl, true, false, 2),
      (ApiServiceConstants.publicliquidElectrumTestUrlPath, true, true, 2),
    ];

    for (final (url, isTestnet, isLiquid, priority) in serversData) {
      final server = ElectrumServerRow(
        url: url,
        stopGap: 20,
        timeout: 5,
        retry: 5,
        validateDomain: true,
        isTestnet: isTestnet,
        isLiquid: isLiquid,
        isActive: false,
        priority: priority,
      );

      await into(electrumServers).insertOnConflictUpdate(server);
    }
  }

  Future<void> clearCacheTables() async {
    final cacheTables = [transactions];

    for (final table in cacheTables) {
      await delete(table).go();
    }
  }
}
