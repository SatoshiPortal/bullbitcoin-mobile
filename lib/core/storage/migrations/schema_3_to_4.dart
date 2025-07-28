import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Migration from version 3 to 4
///
/// Changes:
/// - Renames 'source' column to 'signer' in wallet_metadatas table
/// - Maps old source values to new signer enum values:
///   - 'mnemonic' → 'local'
///   - 'descriptors' → 'remote'
///   - others → 'none'
class Schema3To4 {
  static Future<void> migrate(Migrator m, Schema4 schema4) async {
    final schema3 = Schema3(database: m.database);

    // Rename source column to signer
    await m.renameColumn(
      schema4.walletMetadatas,
      schema3.walletMetadatas.source.name,
      schema4.walletMetadatas.signer,
    );

    // Map old wallet_source values to new signer enum values
    await m.database.customStatement('''
    UPDATE wallet_metadatas
    SET signer = CASE signer
      WHEN 'mnemonic' THEN 'local'
      WHEN 'descriptors' THEN 'remote'
      ELSE 'none'
    END''');

    // Add signerDevice column
    await m.addColumn(
      schema4.walletMetadatas,
      schema4.walletMetadatas.signerDevice,
    );

    // Replace 1667h by 1776h and 1668h by 1h in the id column
    await m.database.customStatement('''
      UPDATE wallet_metadatas
      SET id = REPLACE(id, '/1667h/', '/1776h/')
      WHERE id LIKE '%/1667h/%';

      UPDATE wallet_metadatas
      SET id = REPLACE(id, '/1668h/', '/1h/')
      WHERE id LIKE '%/1668h/%';
      ''');

    // Delete table wallet_address_history
    await m.deleteTable(schema3.walletAddressHistory.actualTableName);

    // Create table wallet_addresses
    await m.createTable(schema4.walletAddresses);
  }
}
