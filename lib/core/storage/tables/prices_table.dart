import 'package:drift/drift.dart';

@DataClassName('PriceRow')
class Prices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fromCurrency => text()();
  TextColumn get toCurrency => text()();
  TextColumn get interval => text()();
  RealColumn get marketPrice => real().nullable()();
  RealColumn get price => real().nullable()();
  TextColumn get priceCurrency => text().nullable()();
  IntColumn get precision => integer().nullable()();
  RealColumn get indexPrice => real().nullable()();
  RealColumn get userPrice => real().nullable()();
  TextColumn get createdAt => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {fromCurrency, toCurrency, interval, createdAt},
  ];
}
