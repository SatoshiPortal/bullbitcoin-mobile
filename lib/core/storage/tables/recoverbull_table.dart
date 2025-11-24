import 'package:drift/drift.dart';

@DataClassName('RecoverbullRow')
class Recoverbull extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get url => text()();
  BoolColumn get isPermissionGranted => boolean()();
}
