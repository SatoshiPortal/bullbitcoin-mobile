import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'payjoin_database.g.dart';

@DataClassName('PayjoinSenderRow')
class PayjoinSenders extends Table {
  TextColumn get uri => text()();
  BoolColumn get isTestnet => boolean()();
  TextColumn get sender => text()();
  TextColumn get walletId => text()();
  TextColumn get originalPsbt => text()();
  TextColumn get originalTxId => text()();
  IntColumn get amountSat => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get expireAfterSec => integer()();
  // Existing schema-v1 sessions have unknown origin. Fail closed during the
  // migration so an old exchange payjoin never gains a manual fallback.
  BoolColumn get isExchange => boolean().withDefault(const Constant(true))();
  TextColumn get proposalPsbt => text().nullable()();
  TextColumn get txId => text().nullable()();
  BoolColumn get isExpired => boolean()();
  BoolColumn get isCompleted => boolean()();
  BoolColumn get isAborted => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {uri};
}

@DataClassName('PayjoinReceiverRow')
class PayjoinReceivers extends Table {
  TextColumn get id => text()();
  TextColumn get address => text()();
  BoolColumn get isTestnet => boolean()();
  TextColumn get receiver => text()();
  TextColumn get walletId => text()();
  TextColumn get pjUri => text()();
  Int64Column get maxFeeRateSatPerVb => int64()();
  IntColumn get createdAt => integer()();
  IntColumn get expireAfterSec => integer()();
  // New sessions always persist an explicit value from their start request.
  BoolColumn get isExchange => boolean().withDefault(const Constant(true))();
  BlobColumn get originalTxBytes => blob().nullable()();
  TextColumn get originalTxId => text().nullable()();
  IntColumn get amountSat => integer().nullable()();
  TextColumn get proposalPsbt => text().nullable()();
  TextColumn get txId => text().nullable()();
  BoolColumn get isExpired => boolean()();
  BoolColumn get isCompleted => boolean()();
  BoolColumn get isAborted => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PayjoinPolicyRow')
class PayjoinPolicies extends Table {
  IntColumn get id => integer()();
  BoolColumn get enabled => boolean()();
  IntColumn get minimumAmountSat => integer()();
  IntColumn get sessionLifetimeSeconds => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PayjoinMigrationRow')
class PayjoinMigrations extends Table {
  TextColumn get name => text()();
  DateTimeColumn get completedAt => dateTime()();
  IntColumn get sourceSchemaVersion => integer()();
  IntColumn get senderCount => integer()();
  IntColumn get receiverCount => integer()();
  TextColumn get verificationDigest => text()();

  @override
  Set<Column<Object>> get primaryKey => {name};
}

@DriftDatabase(
  tables: [
    PayjoinSenders,
    PayjoinReceivers,
    PayjoinPolicies,
    PayjoinMigrations,
  ],
)
final class PayjoinDatabase extends _$PayjoinDatabase {
  static const schema = 2;

  PayjoinDatabase._(super.executor);

  factory PayjoinDatabase.open(String path) {
    return PayjoinDatabase._(
      NativeDatabase.createInBackground(
        File(path),
        setup: (database) {
          database.execute('PRAGMA busy_timeout = 2000;');
          database.execute('PRAGMA journal_mode = WAL;');
          database.execute('PRAGMA synchronous = FULL;');
        },
      ),
    );
  }

  factory PayjoinDatabase.forTesting(QueryExecutor executor) =
      PayjoinDatabase._;

  @override
  int get schemaVersion => schema;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(payjoinSenders, payjoinSenders.isExchange);
        await migrator.addColumn(payjoinReceivers, payjoinReceivers.isExchange);
      }
    },
  );
}
