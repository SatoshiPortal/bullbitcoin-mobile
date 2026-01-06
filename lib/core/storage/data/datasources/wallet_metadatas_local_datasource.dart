part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [WalletMetadatas])
class WalletMetadatasLocalDatasource extends DatabaseAccessor<SqliteDatabase>
    with _$WalletMetadatasLocalDatasourceMixin {
  WalletMetadatasLocalDatasource(super.attachedDatabase);

  Future<void> store(WalletMetadataRow row) {
    return into(walletMetadatas).insertOnConflictUpdate(row.toCompanion(true));
  }

  Future<WalletMetadataRow?> fetchById(String id) {
    return attachedDatabase.managers.walletMetadatas
        .filter((e) => e.id(id))
        .getSingleOrNull();
  }

  Future<List<WalletMetadataRow>> fetchAll() {
    return attachedDatabase.managers.walletMetadatas.get();
  }

  Future<void> trashById(String id) {
    return attachedDatabase.managers.walletMetadatas
        .filter((e) => e.id(id))
        .delete();
  }
}
