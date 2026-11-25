import 'package:drift/drift.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/owner_database.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../../domain/recoverbull_failure.dart';
import '../../domain/wallet_backup_usage.dart';
import '../recoverbull_storage_failure.dart';
import 'recoverbull_cutover.dart';
import 'recoverbull_database.dart';
import 'wallet_backup_import.dart';

final class RecoverBullWalletBackups {
  final OwnerDatabase<RecoverBullDatabase> _store;

  const RecoverBullWalletBackups._(this._store);

  @useResult
  static Future<Result<RecoverBullWalletBackups, RecoverBullFailure>> open({
    required RecoverBullCutover cutover,
    required RuntimeAdmission admission,
    required LegacySource legacy,
  }) async {
    switch (await cutover.open(admission)) {
      case Err():
        return const Err(VaultStorageFailure());
      case Ok(:final value):
        var published = false;
        try {
          await importLegacyWalletBackupUsages(
            value.database,
            legacy,
            regtest: cutover.regtest,
          );
          published = true;
          return Ok(RecoverBullWalletBackups._(value));
        } on Exception catch (error) {
          return Err(recoverBullStorageFailure(error));
        } finally {
          if (!published) await value.handle.close();
        }
    }
  }

  RecoverBullDatabase get _database => _store.database;

  @useResult
  Future<Result<WalletBackupUsage?, RecoverBullFailure>> read(
    String walletId,
  ) => _result(() async {
    final query = _database.select(_database.recoverbullWalletBackups)
      ..where((row) => row.walletId.equals(walletId));
    final row = await query.getSingleOrNull();
    return row == null ? null : backupUsageFromRow(row);
  });

  /// Claims a wallet usage without changing evidence for another identity.
  /// Existing members retain the evidence for their already-authorized seed.
  @internal
  Future<Result<void, RecoverBullFailure>> prepare(
    WalletBackupUsage usage, {
    required bool preserveVerified,
  }) => _result(
    () => _database.transaction(() async {
      final table = _database.recoverbullWalletBackups;
      // Claim the write lock before reading, including across connections.
      await _database.customStatement(
        'UPDATE recoverbull_wallet_backups SET wallet_id = wallet_id WHERE wallet_id = ?',
        [usage.walletId],
      );
      final existing = await (_database.select(
        table,
      )..where((row) => row.walletId.equals(usage.walletId))).getSingleOrNull();
      if (existing != null &&
          existing.secretFingerprint != usage.secretFingerprint) {
        throw const FormatException('wallet backup identity mismatch');
      }
      if (existing != null && preserveVerified) return;
      await _database
          .into(table)
          .insertOnConflictUpdate(backupUsageCompanion(usage));
    }),
  );

  /// Records a successful challenge for the verified secret in this store.
  @useResult
  Future<Result<void, RecoverBullFailure>> recordPhysicalVerification({
    required String walletId,
    required Fingerprint fingerprint,
  }) async {
    try {
      final table = _database.recoverbullWalletBackups;
      final verifiedWallet = table.createAlias('verified_wallet');
      final changed =
          await (_database.update(table)..where(
                (row) =>
                    row.secretFingerprint.equals(fingerprint.hex) &
                    existsQuery(
                      _database.selectOnly(verifiedWallet)
                        ..addColumns([verifiedWallet.walletId])
                        ..where(
                          verifiedWallet.walletId.equals(walletId) &
                              verifiedWallet.secretFingerprint.equals(
                                fingerprint.hex,
                              ),
                        ),
                    ),
              ))
              .write(
                RecoverbullWalletBackupsCompanion(
                  physicalBackupTested: const Value(true),
                  latestPhysicalBackup: Value(
                    DateTime.now().millisecondsSinceEpoch,
                  ),
                ),
              );
      return changed == 0 ? const Err(VaultStorageFailure()) : const Ok(null);
    } on Exception catch (error) {
      return Err(recoverBullStorageFailure(error));
    }
  }

  @useResult
  Future<Result<SecretBackupProjection, RecoverBullFailure>> projection(
    Fingerprint fingerprint, {
    String? excludingWalletId,
  }) => _result(
    () => readSecretBackupProjection(
      _database,
      fingerprint.hex,
      excludingWalletId: excludingWalletId,
    ),
  );

  Future<Result<T, RecoverBullFailure>> _result<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return Ok(await operation());
    } on Exception catch (error) {
      return Err(recoverBullStorageFailure(error));
    }
  }

  Future<void> close() => _store.handle.close();
}

/// Fixture-only access; exposed exclusively from the testing library.
Future<Result<void, RecoverBullFailure>> writeWalletBackupForTesting(
  RecoverBullWalletBackups backups,
  WalletBackupUsage usage,
) => backups._result(() async {
  await backups._database
      .into(backups._database.recoverbullWalletBackups)
      .insertOnConflictUpdate(backupUsageCompanion(usage));
});

Future<Result<void, RecoverBullFailure>> removeWalletBackupForTesting(
  RecoverBullWalletBackups backups,
  String walletId,
) => backups._result(() async {
  await (backups._database.delete(
    backups._database.recoverbullWalletBackups,
  )..where((row) => row.walletId.equals(walletId))).go();
});
