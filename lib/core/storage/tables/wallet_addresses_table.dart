import 'package:drift/drift.dart';

@DataClassName('WalletAddressRow')
class WalletAddresses extends Table {
  TextColumn get address => text()();
  TextColumn get walletId => text()();
  IntColumn get index => integer()();
  BoolColumn get isChange => boolean()();
  IntColumn get balanceSat => integer()();
  IntColumn get nrOfTransactions => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {address};
}
