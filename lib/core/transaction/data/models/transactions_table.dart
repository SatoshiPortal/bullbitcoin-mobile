import 'package:drift/drift.dart';

class Transactions extends Table {
  TextColumn get txid => text()();

  IntColumn get version => integer()();
  TextColumn get size => text()();
  TextColumn get vsize => text()();
  IntColumn get locktime => integer()();

  TextColumn get vin => text()();
  TextColumn get vout => text()();

  TextColumn? get blockhash => text().nullable()();
  IntColumn? get height => integer().nullable()();
  IntColumn? get confirmations => integer().nullable()();
  IntColumn? get time => integer().nullable()();
  IntColumn? get blocktime => integer().nullable()();

  @override
  Set<Column> get primaryKey => {txid};
}
