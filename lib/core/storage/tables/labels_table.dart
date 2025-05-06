import 'package:drift/drift.dart';

@DataClassName('LabelRow')
class Labels extends Table {
  TextColumn get label => text()();
  TextColumn get ref => text()();
  TextColumn get type => text()();
  TextColumn get origin => text().nullable()();
  BoolColumn get spendable => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {label, ref};
}
