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
    await db.customStatement(
      'ALTER TABLE wallet_metadatas RENAME COLUMN source TO signer',
    );

    // Map old wallet_source values to new signer enum values
    await db.customStatement('''
    UPDATE wallet_metadatas
    SET signer = CASE signer
      WHEN 'mnemonic' THEN 'local'
      WHEN 'descriptors' THEN 'remote'
      ELSE 'none'
    END''');
  }
}
