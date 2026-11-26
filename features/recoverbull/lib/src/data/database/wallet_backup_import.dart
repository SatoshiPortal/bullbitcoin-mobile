import 'package:drift/drift.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:legacy_storage/owner_database.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../domain/recoverbull_failure.dart';
import '../../domain/wallet_backup_usage.dart';
import 'recoverbull_cutover.dart';
import 'recoverbull_database.dart';

const _receiptId = 'split-v1/recoverbull-wallet-backups';

/// Import already projected usages under exclusive admission and verify a replay.
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
  try {
    await _importOnce(store.database, () => usages, verifyRecorded: true);
    return const Ok(null);
  } on Exception {
    return const Err(VaultStorageFailure());
  } finally {
    await store.handle.close();
  }
}

/// Whether the secondary receipt of the wallet-backup projection is recorded
/// in this cutover's own encrypted store. Read-only, under exclusive admission.
Future<Result<bool, LegacyImportFailure>> hasWalletBackupReceipt({
  required RecoverBullCutover cutover,
  required ExclusiveAdmission admission,
}) async {
  final opened = await cutover.openForInventory(admission);
  switch (opened) {
    case Err(:final failure):
      return Err(failure);
    case Ok(:final value):
      try {
        return await hasLegacyImportReceipt(value.database, _receiptId);
      } finally {
        await value.handle.close();
      }
  }
}

/// The shared runtime admission keeps the legacy family alive while this
/// synchronous read takes a snapshot of the retired wallet columns.
Future<void> importLegacyWalletBackupUsages(
  RecoverBullDatabase database,
  LegacySource legacy, {
  required bool regtest,
}) => _importOnce(database, () {
  if (legacy.schemaVersion != splitV1SourceSchemaVersion) {
    throw const _BackupImportMismatch();
  }
  final source = sqlite.sqlite3.open(
    legacy.file.path,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    source.execute('BEGIN');
    if (source.userVersion != legacy.schemaVersion) {
      throw const _BackupImportMismatch();
    }
    final rows = source.select(
      '''
      SELECT id, CASE WHEN signer = 'local' THEN master_fingerprint END,
             is_encrypted_vault_tested, is_physical_backup_tested,
             latest_encrypted_backup, latest_physical_backup
      FROM wallet_metadatas
      WHERE (network IN ('bitcoinRegtest', 'liquidRegtest')) = ?
      ORDER BY id
    ''',
      [regtest ? 1 : 0],
    );
    return [
      for (final row in rows)
        switch (row.values.toList()) {
          [
            final String id,
            final String? fingerprint,
            final int encrypted,
            final int physical,
            final int? latestEncrypted,
            final int? latestPhysical,
          ]
              when (encrypted == 0 || encrypted == 1) &&
                  (physical == 0 || physical == 1) =>
            (
              walletId: id,
              secretFingerprint: fingerprint,
              encryptedVaultTested: encrypted == 1,
              physicalBackupTested: physical == 1,
              latestEncryptedBackup: latestEncrypted,
              latestPhysicalBackup: latestPhysical,
            ),
          _ => throw const _BackupImportMismatch(),
        },
    ];
  } finally {
    source.close();
  }
});

Future<void> _importOnce(
  RecoverBullDatabase database,
  Iterable<WalletBackupUsage> Function() readUsages, {
  bool verifyRecorded = false,
}) => database.transaction(() async {
  // Claim before reading so simultaneous openers observe the same committed
  // result. Failure rolls back both the claim and the copied rows.
  final claimed = await database.customUpdate(
    'INSERT INTO legacy_import_receipts (id) VALUES (?) ON CONFLICT (id) DO NOTHING',
    variables: [const Variable(_receiptId)],
  );
  if (claimed == 0 && !verifyRecorded) return;
  final table = database.recoverbullWalletBackups;
  if (claimed != 0 &&
      await (database.select(table)..limit(1)).getSingleOrNull() != null) {
    throw const _BackupImportMismatch();
  }
  final expected = <String, WalletBackupUsage>{};
  for (final usage in readUsages()) {
    if (expected.containsKey(usage.walletId)) {
      throw const _BackupImportMismatch();
    }
    expected[usage.walletId] = usage;
    if (claimed != 0) {
      await database.into(table).insert(backupUsageCompanion(usage));
    }
  }
  final stored = await database.select(table).get();
  if (stored.length != expected.length ||
      stored.any((row) => expected[row.walletId] != backupUsageFromRow(row))) {
    throw const _BackupImportMismatch();
  }
});

RecoverbullWalletBackupsCompanion backupUsageCompanion(
  WalletBackupUsage usage,
) => RecoverbullWalletBackupsCompanion.insert(
  walletId: usage.walletId,
  secretFingerprint: Value(usage.secretFingerprint),
  encryptedVaultTested: usage.encryptedVaultTested,
  physicalBackupTested: usage.physicalBackupTested,
  latestEncryptedBackup: Value(usage.latestEncryptedBackup),
  latestPhysicalBackup: Value(usage.latestPhysicalBackup),
);

WalletBackupUsage backupUsageFromRow(WalletBackupUsageRow row) => (
  walletId: row.walletId,
  secretFingerprint: row.secretFingerprint,
  encryptedVaultTested: row.encryptedVaultTested,
  physicalBackupTested: row.physicalBackupTested,
  latestEncryptedBackup: row.latestEncryptedBackup,
  latestPhysicalBackup: row.latestPhysicalBackup,
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
  final latestVerified =
      await (database.select(database.recoverbullBackupStatus)
            ..where(
              (row) =>
                  row.fingerprint.equals(fingerprint) &
                  row.verifiedAt.isNotNull(),
            )
            ..orderBy([(row) => OrderingTerm.desc(row.verifiedAt)])
            ..limit(1))
          .getSingleOrNull();
  if (latestVerified?.verifiedAt case final time?) {
    encryptedTested = true;
    final millis = time.millisecondsSinceEpoch;
    if (encrypted == null || millis > encrypted) encrypted = millis;
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
