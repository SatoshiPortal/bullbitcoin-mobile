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

    final metadatas = schema4.walletMetadatas;

    await m.alterTable(
      TableMigration(
        metadatas,
        columnTransformer: {
          metadatas.id: CaseWhenExpression(
            cases: [
              CaseWhen(
                metadatas.id.contains('/1667h/'),
                then: metadatas.id.replace('/1667h/', '/1776h/'),
              ),
              CaseWhen(
                metadatas.id.contains('/1668h/'),
                then: metadatas.id.replace('/1668h/', '/1h/'),
              ),
            ],
            orElse: metadatas.id,
          ),
          metadatas.signer: schema3.walletMetadatas.source.caseMatch(
            when: {
              const Constant('mnemonic'): const Constant('local'),
              const Constant('descriptors'): const Constant('remote'),
            },
            orElse: const Constant('none'),
          ),
        },
        newColumns: [metadatas.signerDevice],
      ),
    );

    // Delete table wallet_address_history
    await m.deleteTable(schema3.walletAddressHistory.actualTableName);

    // Create table wallet_addresses
    await m.createTable(schema4.walletAddresses);
  }
}

extension on Expression<String> {
  Expression<String> replace(String a, String b) {
    return FunctionCallExpression('REPLACE', [this, Variable(a), Variable(b)]);
  }
}
