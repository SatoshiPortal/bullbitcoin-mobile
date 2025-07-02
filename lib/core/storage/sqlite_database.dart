import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/tables/auto_swap.dart';
import 'package:bb_mobile/core/storage/tables/electrum_servers_table.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/storage/tables/payjoin_receivers_table.dart';
import 'package:bb_mobile/core/storage/tables/payjoin_senders_table.dart';
import 'package:bb_mobile/core/storage/tables/settings_table.dart';
import 'package:bb_mobile/core/storage/tables/swaps_table.dart';
import 'package:bb_mobile/core/storage/tables/transactions_table.dart';
import 'package:bb_mobile/core/storage/tables/wallet_address_history_table.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
    AutoSwap,
    WalletAddressHistory,
  ],
)
class SqliteDatabase extends _$SqliteDatabase {
  SqliteDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

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
          _seedDefaultAutoSwap(),
        ]);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Create AutoSwap table and seed it
          await m.createTable(autoSwap);
          await _seedDefaultAutoSwap();
        }
        if (from < 3) {
          // Create WalletAddressHistory table
          await m.createTable(walletAddressHistory);
          // TODO: Should we seed this table with already generated addresses here?
        }
      },
    );
  }

  Future<void> _seedDefaultSettings() async {
    log.info('[SqliteDatabase] seeding default settings...');
    await into(settings).insert(
      SettingsRow(
        id: 1,
        environment: Environment.mainnet.name,
        bitcoinUnit: BitcoinUnit.btc.name,
        language: Language.unitedStatesEnglish.name,
        currency: 'USD',
        hideAmounts: false,
        isSuperuser: false,
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

  Future<void> _seedDefaultAutoSwap() async {
    log.info('[SqliteDatabase] seeding default auto swap settings...');
    await into(autoSwap).insert(
      const AutoSwapRow(
        id: 1,
        enabled: false,
        balanceThresholdSats: 1000000,
        feeThresholdPercent: 3.0,
        blockTillNextExecution: false,
        alwaysBlock: false,
      ),
    );
    await into(autoSwap).insert(
      const AutoSwapRow(
        id: 2,
        enabled: false,
        balanceThresholdSats: 1000000,
        feeThresholdPercent: 3.0,
        blockTillNextExecution: false,
        alwaysBlock: false,
      ),
    );
  }

  Future<void> clearCacheTables() async {
    final cacheTables = [transactions];

    for (final table in cacheTables) {
      await delete(table).go();
    }
  }
}
