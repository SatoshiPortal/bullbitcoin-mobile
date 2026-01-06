part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [Bip85Derivations])
class Bip85DerivationsLocalDatasource extends DatabaseAccessor<SqliteDatabase>
    with _$Bip85DerivationsLocalDatasourceMixin {
  Bip85DerivationsLocalDatasource(super.attachedDatabase);

  Future<void> store(Bip85DerivationRow row) {
    return into(bip85Derivations).insert(row.toCompanion(true));
  }

  Future<Bip85DerivationRow?> fetchByPath(String path) {
    return attachedDatabase.managers.bip85Derivations
        .filter((b) => b.path(path))
        .getSingleOrNull();
  }

  Future<List<Bip85DerivationRow>> fetchByApplication(
    Bip85ApplicationColumn application,
  ) {
    return attachedDatabase.managers.bip85Derivations
        .filter((b) => b.application(application))
        .get();
  }

  Future<List<Bip85DerivationRow>> fetchAll() {
    return attachedDatabase.managers.bip85Derivations.get();
  }

  Future<void> patchStatusByPath({
    required String path,
    required Bip85StatusColumn status,
  }) {
    return attachedDatabase.managers.bip85Derivations
        .filter((b) => b.path(path))
        .update((b) => b(status: Value(status)));
  }

  Future<void> patchAliasByPath({required String path, required String alias}) {
    return attachedDatabase.managers.bip85Derivations
        .filter((b) => b.path(path))
        .update((b) => b(alias: Value(alias)));
  }
}
