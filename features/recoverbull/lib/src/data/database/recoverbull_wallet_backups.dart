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

  @useResult
  Future<Result<void, RecoverBullFailure>> write(WalletBackupUsage usage) =>
      _result(() async {
        await _database
            .into(_database.recoverbullWalletBackups)
            .insertOnConflictUpdate(backupUsageCompanion(usage));
      });

  @useResult
  Future<Result<void, RecoverBullFailure>> remove(String walletId) =>
      _result(() async {
        await (_database.delete(
          _database.recoverbullWalletBackups,
        )..where((row) => row.walletId.equals(walletId))).go();
      });

  @useResult
  Future<Result<SecretBackupProjection, RecoverBullFailure>> projection(
    Fingerprint fingerprint,
  ) => _result(() => readSecretBackupProjection(_database, fingerprint.hex));

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
