import 'package:drift/drift.dart';

/// Frozen legacy permission projection; the legacy URL is never copied.
class RecoverbullPermissions extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get isPermissionGranted => boolean()();

  @override
  String get tableName => 'recoverbull';
}

/// A newer permission from the standalone v1 file, isolated by file family.
class RecoverbullPermissionOverrides extends Table {
  TextColumn get family => text()();
  BoolColumn get isPermissionGranted => boolean()();
  IntColumn get revision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {family};
}
