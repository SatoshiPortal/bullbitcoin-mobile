import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/migrations/schema_3_to_4.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/core/storage/tables/auto_swap.dart';
import 'package:bb_mobile/core/storage/tables/electrum_servers_table.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/storage/tables/payjoin_receivers_table.dart';
import 'package:bb_mobile/core/storage/tables/payjoin_senders_table.dart';
import 'package:bb_mobile/core/storage/tables/settings_table.dart';
import 'package:bb_mobile/core/storage/tables/swaps_table.dart';
import 'package:bb_mobile/core/storage/tables/transactions_table.dart';
import 'package:bb_mobile/core/storage/tables/wallet_addresses_table.dart';
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
    WalletAddresses,
  ],
)
class SqliteDatabase extends _$SqliteDatabase {
  SqliteDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'bullbitcoin_sqlite',
      native: DriftNativeOptions(
        /// When using a shared instance, stream queries synchronize across the two
        /// isolates. Also, drift then manages concurrent access to the database,
        /// preventing "database is locked" errors due to concurrent transactions.
        shareAcrossIsolates: true,
        setup: (database) {
          // This is important, as accessing the database across threads otherwise
          // causes "database locked" errors.
          // With write-ahead logging (WAL) enabled, a single writer and multiple
          // readers can operate on the database in parallel.
          database.execute('pragma journal_mode = WAL;');
        },
      ),
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
      onUpgrade: stepByStep(
        from1To2: (m, schema) async {
          // Create AutoSwap table and seed it
          await m.createTable(autoSwap);
          await _seedDefaultAutoSwap();
        },
        from2To3: (m, schema) async {
          // Create WalletAddressHistory table
          await m.createTable(schema.walletAddressHistory);
        },
        from3To4: Schema3To4.migrate,
      ),
    );
  }

  Future<void> _seedDefaultSettings() async {
    log.info('[SqliteDatabase] seeding default settings...');
    await into(settings).insert(
      SettingsRow(
        id: 1,
        environment: Environment.mainnet.name,
        bitcoinUnit: BitcoinUnit.sats.name,
        language: Language.unitedStatesEnglish.name,
        currency: 'CAD',
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
