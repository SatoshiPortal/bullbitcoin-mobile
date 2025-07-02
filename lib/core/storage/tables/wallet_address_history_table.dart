import 'package:drift/drift.dart';

@DataClassName('WalletAddressHistoryRow')
class WalletAddressHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get address => text()();
  TextColumn get walletId => text()();
  IntColumn get index => integer()();
  BoolColumn get isChange => boolean()();
  IntColumn get balanceSat => integer()();
  IntColumn get nrOfTransactions => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
