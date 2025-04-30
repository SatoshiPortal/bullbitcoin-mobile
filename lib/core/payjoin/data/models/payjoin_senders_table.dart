import 'package:drift/drift.dart';

@DataClassName('PayjoinSenderModel')
class PayjoinSenders extends Table {
  TextColumn get uri => text()();
  TextColumn get sender => text()();
  TextColumn get walletId => text()();
  TextColumn get originalPsbt => text()();
  TextColumn get originalTxId => text()();
  IntColumn get expireAt => integer()();
  TextColumn get proposalPsbt => text().nullable()();
  TextColumn get txId => text().nullable()();
  BoolColumn get isExpired => boolean()();
  BoolColumn get isCompleted => boolean()();

  @override
  Set<Column> get primaryKey => {uri};
}
