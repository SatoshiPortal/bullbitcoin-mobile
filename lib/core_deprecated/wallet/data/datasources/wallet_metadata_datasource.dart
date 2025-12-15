import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/models/wallet_metadata_model.dart';

class WalletMetadataDatasource {
  final SqliteDatabase _sqlite;

  WalletMetadataDatasource({required SqliteDatabase sqlite}) : _sqlite = sqlite;

  Future<void> store(WalletMetadataModel metadata) async {
    final companion = metadata.toSqlite();
    await _sqlite
        .into(_sqlite.walletMetadatas)
        .insertOnConflictUpdate(companion);
  }

  Future<WalletMetadataModel?> fetch(String walletId) async {
    final row = await _sqlite.managers.walletMetadatas
        .filter((e) => e.id(walletId))
        .getSingleOrNull();

    if (row == null) return null;
    return WalletMetadataModelMapper.fromSqlite(row);
  }

  Future<List<WalletMetadataModel>> fetchAll() async {
    final rows = await _sqlite.managers.walletMetadatas.get();
    return rows.map((e) => WalletMetadataModelMapper.fromSqlite(e)).toList();
  }

  Future<void> delete(String walletId) async {
    await _sqlite.managers.walletMetadatas
        .filter((e) => e.id(walletId))
        .delete();
  }
}
