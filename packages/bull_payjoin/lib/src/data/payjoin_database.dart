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
  BlobColumn get originalTxBytes => blob().nullable()();
  TextColumn get originalTxId => text().nullable()();
  IntColumn get amountSat => integer().nullable()();
  TextColumn get proposalPsbt => text().nullable()();
  TextColumn get txId => text().nullable()();
  BoolColumn get isExpired => boolean()();
  BoolColumn get isCompleted => boolean()();
  BoolColumn get isAborted => boolean()();
  // Session created for a Bull Bitcoin exchange trade (buy order payout).
  // Gated by PayjoinPolicies.tradingEnabled instead of enabled — see
  // PayjoinEngine.isReceiverAllowed. Defaulted so pre-existing rows from
  // schema 1 (all created through the enabled-gated flows) stay non-trade.
  BoolColumn get isTrade => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PayjoinPolicyRow')
class PayjoinPolicies extends Table {
  IntColumn get id => integer()();
  BoolColumn get enabled => boolean()();
  // Payjoin for exchange trades; independent of `enabled` and defaults ON —
  // see PayjoinPolicy.tradingEnabled.
  BoolColumn get tradingEnabled =>
      boolean().withDefault(const Constant(true))();
  // Payjoin on regular sends; independent of both switches above and
  // defaults ON — see PayjoinPolicy.sendEnabled.
  BoolColumn get sendEnabled => boolean().withDefault(const Constant(true))();
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
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // The column defaults do the data migration: the existing policy row
        // gets tradingEnabled=true (the feature's default), and existing
        // receiver rows get isTrade=false (they were all created through the
        // enabled-gated flows).
        await m.addColumn(payjoinPolicies, payjoinPolicies.tradingEnabled);
        await m.addColumn(payjoinPolicies, payjoinPolicies.sendEnabled);
        await m.addColumn(payjoinReceivers, payjoinReceivers.isTrade);
      }
    },
  );
}
