import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:drift/drift.dart';

/// Migration from version 4 to 5
///
/// Changes:
/// - Add column signerDevice
/// - Replace 1667h by 1776h and 1668h by 1777h in the id column
class SchemaV5 {
  static Future<void> migrate(
    Migrator m,
    TableInfo<WalletMetadatas, dynamic> walletMetadatas,
  ) async {
    // Add signerDevice column
    await m.addColumn(
      walletMetadatas,
      GeneratedColumn(
        'signer_device',
        walletMetadatas.aliasedName,
        true,
        type: DriftSqlType.string,
      ),
    );

    // Replace 1667h by 1776h and 1668h by 1777h in the id column
    await m.database.customStatement('''
      UPDATE wallet_metadatas
      SET id = REPLACE(id, '/1667h/', '/1776h/')
      WHERE id LIKE '%/1667h/%';

      UPDATE wallet_metadatas
      SET id = REPLACE(id, '/1668h/', '/1777h/')
      WHERE id LIKE '%/1668h/%';
      ''');
  }
}
