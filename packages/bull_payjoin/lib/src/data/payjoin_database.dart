import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'payjoin_database.steps.dart';

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
  // A payment of this session may be on the network without a recorded
  // outcome: one of its transactions went to broadcast or was observed. Such
  // a session is never expired from a later negative lookup. Senders that
  // were unfinished when schema 3 arrived are assumed to hold it.
  BoolColumn get hasNetworkEvidence =>
      boolean().withDefault(const Constant(false))();

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
  // A buy order payout from the Bull Bitcoin exchange, gated by the buy
  // switch instead of the receive switch. Schema 1 rows were all created by
  // the receive flow, hence the default.
  BoolColumn get isTrade => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PayjoinPolicyRow')
class PayjoinPolicies extends Table {
  IntColumn get id => integer()();
  // Schema 1's single switch; it now governs receiving from users only.
  BoolColumn get receiveEnabled => boolean().named('enabled')();
  BoolColumn get sendEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get buyEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get sellEnabled => boolean().withDefault(const Constant(true))();
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
  static const schema = 3;

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
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(
          schema.payjoinReceivers,
          schema.payjoinReceivers.isTrade,
        );
        await m.addColumn(
          schema.payjoinPolicies,
          schema.payjoinPolicies.sendEnabled,
        );
        await m.addColumn(
          schema.payjoinPolicies,
          schema.payjoinPolicies.buyEnabled,
        );
        await m.addColumn(
          schema.payjoinPolicies,
          schema.payjoinPolicies.sellEnabled,
        );
        // The single switch used to gate sending as well: a user who turned
        // it on keeps payjoin on both sides of a payment with another user.
        await customStatement(
          'UPDATE payjoin_policies SET send_enabled = enabled',
        );
      },
      from2To3: (m, schema) async {
        try {
          // One transaction: the column never exists without its backfill.
          await transaction(() async {
            await m.addColumn(
              schema.payjoinSenders,
              schema.payjoinSenders.hasNetworkEvidence,
            );
            // Schema 2 kept no trace of a payment that went out without a
            // recorded outcome. An unfinished sender is therefore assumed to
            // hold evidence; only sessions created from now on start without.
            await customStatement(
              'UPDATE payjoin_senders SET has_network_evidence = 1 '
              'WHERE is_expired = 0 AND is_completed = 0 AND is_aborted = 0',
            );
          });
        } catch (e) {
          // A re-run, or another connection migrating at the same time, finds
          // the column already there with its backfill: nothing left to do,
          // and never a second backfill over later rows. Anything else is a
          // real storage failure.
          if (!'$e'.contains('duplicate column name: has_network_evidence')) {
            rethrow;
          }
          final columns = await customSelect(
            "PRAGMA table_info('payjoin_senders')",
          ).get();
          if (!columns.any(
            (column) => column.read<String>('name') == 'has_network_evidence',
          )) {
            rethrow;
          }
        }
      },
    ),
  );
}
