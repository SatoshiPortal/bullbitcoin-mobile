import 'package:drift/drift.dart';

part 'boltz_swaps_database.g.dart';

/// Stored by name; the values are wire format carried over unchanged from the
/// app database's swaps table ('send', 'receive', 'onchain').
enum SwapRowDirection { send, receive, onchain }

/// Column-for-column the app database's `swaps` table at its final state
/// (app schema v14) — the migration copies rows across verbatim.
@DataClassName('SwapRow')
class Swaps extends Table {
  TextColumn get id => text().withLength(min: 12, max: 12)();
  TextColumn get type => text()();
  TextColumn get direction => textEnum<SwapRowDirection>()();
  TextColumn get status => text()();
  BoolColumn get isTestnet => boolean()();
  IntColumn get keyIndex => integer()();
  IntColumn get creationTime => integer()();
  IntColumn get completionTime => integer().nullable()();
  TextColumn get receiveWalletId => text().nullable()();
  TextColumn get sendWalletId => text().nullable()();
  TextColumn get invoice => text().nullable()();
  TextColumn get paymentAddress => text().nullable()();
  IntColumn get paymentAmount => integer().nullable()();
  TextColumn get receiveAddress => text().nullable()();
  TextColumn get receiveTxid => text().nullable()();
  TextColumn get sendTxid => text().nullable()();
  TextColumn get preimage => text().nullable()();
  TextColumn get refundAddress => text().nullable()();
  TextColumn get refundTxid => text().nullable()();
  IntColumn get boltzFees => integer().nullable()();
  IntColumn get lockupFees => integer().nullable()();
  IntColumn get claimFees => integer().nullable()();
  IntColumn get refundFees => integer().nullable()();
  IntColumn get serverNetworkFees => integer().nullable()();
  BoolColumn get wasDirectPayment =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get recovered => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per completed one-shot data migration (e.g. the legacy import
/// from the app database), so completion is committed atomically with the
/// imported rows instead of living in a separate preferences flag.
class SwapDataMigrations extends Table {
  TextColumn get name => text()();
  IntColumn get completedAt => integer()();

  @override
  Set<Column> get primaryKey => {name};
}

/// The engine's own database. The app injects the [QueryExecutor] (file
/// location, WAL/busy-timeout pragmas, cross-isolate sharing are the app's
/// platform concerns) so this package stays pure Dart.
@DriftDatabase(tables: [Swaps, SwapDataMigrations])
class BoltzSwapsDatabase extends _$BoltzSwapsDatabase {
  static const String name = 'boltz_swaps';

  BoltzSwapsDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  Future<bool> dataMigrationDone(String migrationName) async =>
      await (select(
        swapDataMigrations,
      )..where((row) => row.name.equals(migrationName))).getSingleOrNull() !=
      null;

  /// Runs [import] and records [migrationName] as done in ONE transaction:
  /// either every imported row and the marker commit together, or nothing
  /// does. Skips silently when the marker already exists.
  Future<void> runDataMigration(
    String migrationName,
    Future<void> Function() import,
  ) async {
    if (await dataMigrationDone(migrationName)) return;
    await transaction(() async {
      // Re-check inside the transaction, and insert the marker with
      // insertOrIgnore: two isolates racing the first launch both import
      // (idempotent when the import itself is insert-if-absent) and both
      // commit cleanly instead of one failing on the marker's primary key.
      if (await dataMigrationDone(migrationName)) return;
      await import();
      await into(swapDataMigrations).insert(
        SwapDataMigrationsCompanion.insert(
          name: migrationName,
          completedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }
}
