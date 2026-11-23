import 'package:drift/drift.dart';

enum LabelTypeColumn { tx, address, pubkey, input, output, xpub }

@DataClassName('LabelRow')
class LabelsTable extends Table {
  @override
  String get tableName => 'labels';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text()();
  TextColumn get reference => text()();
  TextColumn get type => textEnum<LabelTypeColumn>()();
  TextColumn get origin => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {label, reference},
  ];
}
