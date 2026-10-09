import 'package:drift/drift.dart';

@DataClassName('KeychainNostrKeyRow')
class KeychainNostrKeys extends Table {
  TextColumn get publicKey => text()();
  TextColumn get parentFingerprint => text()();
  IntColumn get identity => integer()();
  TextColumn get purpose => text()();
  TextColumn get description => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {publicKey};

  @override
  List<Set<Column>> get uniqueKeys => [
    {parentFingerprint, identity},
  ];
}
