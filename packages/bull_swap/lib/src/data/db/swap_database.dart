import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'swap_database.g.dart';

enum SwapDirection { send, receive, onchain }

@DataClassName('SwapRow')
class Swaps extends Table {
  TextColumn get id => text().withLength(min: 12, max: 12)();
  TextColumn get type => text()();
  TextColumn get direction => textEnum<SwapDirection>()();
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
  TextColumn get providerId => text().withDefault(const Constant('bull'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AutoSwapRow')
class AutoSwap extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get balanceThresholdSats => integer()();
  IntColumn get triggerBalanceSats => integer()();
  RealColumn get feeThresholdPercent => real()();
  BoolColumn get blockTillNextExecution =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get alwaysBlock => boolean().withDefault(const Constant(false))();
  TextColumn get recipientWalletId => text().nullable()();
  BoolColumn get showWarning => boolean().withDefault(const Constant(true))();
}

@DataClassName('OrderSwapRow')
class OrderSwaps extends Table {
  TextColumn get localId => text()();
  TextColumn get requestId => text().nullable()();
  TextColumn get orderId => text().nullable().unique()();
  TextColumn get purpose => text()();
  TextColumn get environment => text()();
  TextColumn get inNetwork => text()();
  TextColumn get outNetwork => text()();
  BoolColumn get isInAmountFixed => boolean()();
  IntColumn get requestedAmountSat => integer()();
  IntColumn get quotedAmountSat => integer().nullable()();
  TextColumn get sourceWalletId => text().nullable()();
  TextColumn get destinationWalletId => text().nullable()();
  TextColumn get destination => text()();
  TextColumn get fallback => text()();
  TextColumn get bitcoinAddress => text().nullable()();
  TextColumn get liquidAddress => text().nullable()();
  TextColumn get lightningInvoice => text().nullable()();
  IntColumn get payinAmountSat => integer().nullable()();
  IntColumn get payoutAmountSat => integer().nullable()();
  TextColumn get payinCurrency => text().nullable()();
  TextColumn get payoutCurrency => text().nullable()();
  TextColumn get payinMethod => text().nullable()();
  TextColumn get payoutMethod => text().nullable()();
  TextColumn get orderType => text().nullable()();
  TextColumn get orderStatus => text().nullable()();
  TextColumn get payinStatus => text().nullable()();
  TextColumn get payoutStatus => text().nullable()();
  TextColumn get messageCode => text().nullable()();
  TextColumn get bitcoinTransactionId => text().nullable()();
  TextColumn get liquidTransactionId => text().nullable()();
  TextColumn get localPayinTransactionId => text().nullable()();
  TextColumn get signedPayinTransaction => text().nullable()();
  BoolColumn get payinIsPsbt => boolean().nullable()();
  IntColumn get orderNumber => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get serverCreatedAt => dateTime().nullable()();
  DateTimeColumn get confirmationDeadline => dateTime().nullable()();
  DateTimeColumn get sentAt => dateTime().nullable()();
  TextColumn get localStatus => text()();
  DateTimeColumn get lastPolledAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get serverCompletedAt => dateTime().nullable()();
  DateTimeColumn get labelsAppliedAt => dateTime().nullable()();
  TextColumn get providerId => text().withDefault(const Constant('bull'))();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DataClassName('SwapProviderRow')
class SwapProviders extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text().nullable()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SwapMigrationRow')
class SwapMigrations extends Table {
  TextColumn get name => text()();
  IntColumn get completedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {name};
}

@DriftDatabase(
  tables: [Swaps, AutoSwap, OrderSwaps, SwapProviders, SwapMigrations],
)
final class SwapDatabase extends _$SwapDatabase {
  static const schema = 1;

  SwapDatabase._(super.executor);

  factory SwapDatabase.open(String path) {
    return SwapDatabase._(
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

  factory SwapDatabase.forTesting(QueryExecutor executor) = SwapDatabase._;

  @override
  int get schemaVersion => schema;
}
