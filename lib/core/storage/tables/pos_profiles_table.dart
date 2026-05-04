import 'package:drift/drift.dart';

@DataClassName('PosProfileRow')
class PosProfiles extends Table {
  TextColumn get merchantPubkey => text()();
  TextColumn get posId => text()();
  TextColumn get walletId => text()();
  TextColumn get masterFingerprint => text()();
  TextColumn get recoveryPubkey => text()();
  TextColumn get relaysJson => text()();
  TextColumn get network => text()();
  TextColumn get name => text()();
  TextColumn get currency => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {merchantPubkey, posId};
}
