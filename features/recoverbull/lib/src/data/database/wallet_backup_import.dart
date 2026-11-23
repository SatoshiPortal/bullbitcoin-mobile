import 'package:drift/drift.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:legacy_storage/owner_database.dart';
import 'package:primitives/primitives.dart';

import '../../domain/recoverbull_failure.dart';
import '../../domain/wallet_backup_usage.dart';
import 'recoverbull_cutover.dart';
import 'recoverbull_database.dart';

const _receiptId = 'split-v1/recoverbull-wallet-backups';

/// Called by the Secrets inventory participant under its exclusive admission.
/// Never recopy into a populated store without a committed receipt.
Future<Result<void, RecoverBullFailure>> importWalletBackupUsages({
  required RecoverBullCutover cutover,
  required ExclusiveAdmission admission,
  required Iterable<WalletBackupUsage> usages,
}) async {
  final opened = await cutover.openForInventory(admission);
  if (opened case Err()) return const Err(VaultStorageFailure());
  final store =
      (opened as Ok<OwnerDatabase<RecoverBullDatabase>, LegacyImportFailure>)
          .value;
  final database = store.database;
  try {
    await database.transaction(() async {
      final recorded = await hasLegacyImportReceipt(database, _receiptId);
      if (recorded is! Ok<bool, LegacyImportFailure>) {
        throw const _BackupImportMismatch();
      }
      final table = database.recoverbullWalletBackups;
      final existing = await database.select(table).get();
      final expected = {for (final usage in usages) usage.walletId: usage};
      if (expected.length != usages.length) {
        throw const _BackupImportMismatch();
      }
      if (recorded.value) {
        if (!_verified(existing, expected)) {
          throw const _BackupImportMismatch();
        }
        return;
      }
      if (existing.isNotEmpty) throw const _BackupImportMismatch();
      for (final row in expected.values) {
        await database
            .into(table)
            .insert(
              RecoverbullWalletBackupsCompanion.insert(
                walletId: row.walletId,
                secretFingerprint: Value(row.secretFingerprint),
                encryptedVaultTested: row.encryptedVaultTested,
                physicalBackupTested: row.physicalBackupTested,
                latestEncryptedBackup: Value(row.latestEncryptedBackup),
                latestPhysicalBackup: Value(row.latestPhysicalBackup),
              ),
            );
      }
      if (!_verified(await database.select(table).get(), expected)) {
        throw const _BackupImportMismatch();
      }
      await database.customStatement(
        'INSERT INTO legacy_import_receipts (id) VALUES (?)',
        [_receiptId],
      );
    });
    return const Ok(null);
  } on Exception {
    return const Err(VaultStorageFailure());
  } finally {
    await store.handle.close();
  }
}

bool _verified(
  List<WalletBackupUsageRow> stored,
  Map<String, WalletBackupUsage> expected,
) =>
    stored.length == expected.length &&
    stored.every(
      (row) =>
          expected[row.walletId] ==
          (
            walletId: row.walletId,
            secretFingerprint: row.secretFingerprint,
            encryptedVaultTested: row.encryptedVaultTested,
            physicalBackupTested: row.physicalBackupTested,
            latestEncryptedBackup: row.latestEncryptedBackup,
            latestPhysicalBackup: row.latestPhysicalBackup,
          ),
    );

Future<SecretBackupProjection> readSecretBackupProjection(
  RecoverBullDatabase database,
  String fingerprint,
) async {
  final rows = await (database.select(
    database.recoverbullWalletBackups,
  )..where((row) => row.secretFingerprint.equals(fingerprint))).get();
  int? encrypted;
  int? physical;
  var encryptedTested = false;
  var physicalTested = false;
  for (final row in rows) {
    encryptedTested |= row.encryptedVaultTested;
    physicalTested |= row.physicalBackupTested;
    if (row.latestEncryptedBackup case final value?
        when encrypted == null || value > encrypted) {
      encrypted = value;
    }
    if (row.latestPhysicalBackup case final value?
        when physical == null || value > physical) {
      physical = value;
    }
  }
  return (
    encryptedVaultTested: encryptedTested,
    physicalBackupTested: physicalTested,
    latestEncryptedBackup: encrypted,
    latestPhysicalBackup: physical,
  );
}

final class _BackupImportMismatch implements Exception {
  const _BackupImportMismatch();
}
