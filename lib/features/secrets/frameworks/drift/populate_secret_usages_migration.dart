import 'package:bb_mobile/core/primitives/secrets/secret_usage_purpose.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';

/// Migration function to populate secret_usages table from existing wallet_metadata
/// and bip85_derivations tables.
///
/// This function extracts fingerprints from:
/// - wallet_metadata.master_fingerprint (for wallet purposes)
/// - bip85_derivations.xprv_fingerprint (for bip85 purposes)
///
/// Can be called from the main migration strategy.
class PopulateSecretUsagesMigration {
  static Future<void> migrate(Migrator m) async {
    final db = m.database as SqliteDatabase;

    // Get all distinct master fingerprints from wallet_metadata
    final walletMetadataRows = await db.select(db.walletMetadatas).get();

    for (final wallet in walletMetadataRows) {
      final fingerprint = wallet.masterFingerprint;
      final walletId = wallet.id;

      // Insert into secret_usages with wallet purpose
      // Using insertOnConflictUpdate to avoid duplicates based on unique constraint
      await db
          .into(db.secretUsages)
          .insert(
            SecretUsagesCompanion(
              fingerprint: Value(fingerprint),
              purpose: const Value(SecretUsagePurpose.wallet),
              consumerRef: Value(walletId),
            ),
            mode: InsertMode
                .insertOrIgnore, // Ignore if (purpose, consumerRef) exists
          );
    }

    // Get all distinct xprv fingerprints from bip85_derivations
    final bip85Rows = await db.select(db.bip85Derivations).get();

    for (final bip85 in bip85Rows) {
      final fingerprint = bip85.xprvFingerprint;
      final path = bip85.path;

      // Insert into secret_usages with bip85 purpose
      await db
          .into(db.secretUsages)
          .insert(
            SecretUsagesCompanion(
              fingerprint: Value(fingerprint),
              purpose: const Value(SecretUsagePurpose.bip85),
              consumerRef: Value(path),
            ),
            mode: InsertMode
                .insertOrIgnore, // Ignore if (purpose, consumerRef) exists
          );
    }
  }
}
