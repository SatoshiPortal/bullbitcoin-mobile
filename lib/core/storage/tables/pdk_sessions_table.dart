import 'package:drift/drift.dart';

enum PdkSessionType { receiver, sender }

@DataClassName('PdkSessionRow')
class PdkSessions extends Table {
  late final token = text()();

  @override
  Set<Column<Object>> get primaryKey => {token};
  TextColumn get type => textEnum<PdkSessionType>()();
  TextColumn get session => text()();
}
