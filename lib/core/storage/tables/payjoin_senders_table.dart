import 'package:drift/drift.dart';

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

  @override
  Set<Column> get primaryKey => {uri};
}
