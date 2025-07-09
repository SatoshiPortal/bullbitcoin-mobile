import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:drift/drift.dart';

/// Migration from version 3 to 4
///
/// Changes:
/// - Renames 'source' column to 'signer' in wallet_metadatas table
/// - Maps old source values to new signer enum values:
///   - 'mnemonic' → 'local'
///   - 'descriptors' → 'remote'
///   - others → 'none'
class SchemaV4 {
  static Future<void> migrate(
    GeneratedDatabase db,
    TableInfo<WalletMetadatas, dynamic> walletMetadatas,
  ) async {
    // Rename source column to signer
    const sqlRename =
        'ALTER TABLE wallet_metadatas RENAME COLUMN source TO signer';
    await db.customStatement(sqlRename);

    // Select all metadatas
    const sqlSelect = 'SELECT id, signer FROM wallet_metadatas';
    final metadatas = await db.customSelect(sqlSelect).get();

    // Map old source values to new signer enum values
    for (final metadata in metadatas) {
      final id = metadata.read<String>('id');
      final source = metadata.read<String>('signer'); // renamed source

      String signer;
      switch (source) {
        case 'mnemonic':
          signer = Signer.local.name;
        case 'descriptors':
          signer = Signer.remote.name;
        default:
          signer = Signer.none.name;
      }

      // Update the new signer value
      await db.customUpdate(
        'UPDATE wallet_metadatas SET signer = ? WHERE id = ?',
        variables: [Variable.withString(signer), Variable.withString(id)],
      );
    }
  }
}
