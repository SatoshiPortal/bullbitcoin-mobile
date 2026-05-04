import 'package:drift/drift.dart';

@DataClassName('PosObservedEventRow')
class PosObservedEvents extends Table {
  TextColumn get eventId => text()();
  IntColumn get kind => integer()();
  TextColumn get pubkey => text()();
  IntColumn get createdAt => integer()();
  TextColumn get merchantPubkey => text()();
  TextColumn get posId => text()();
  TextColumn get rawJson => text()();

  @override
  Set<Column> get primaryKey => {eventId};
}
