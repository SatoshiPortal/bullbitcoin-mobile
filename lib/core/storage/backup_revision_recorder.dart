import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';

/// Records that a backup-relevant local mutation was committed.
///
/// Owners whose data lives in this database call it from inside the same
/// transaction as the write it records, so no crash window can lose the dirty
/// signal (spec decision 7). Forgetting a wallet depends on that: a lost
/// signal would leave the forgotten wallet in the next published snapshot.
///
/// The contract lives in the storage layer rather than in Bull backup so that
/// an owning feature never has to depend on the backup feature to report its
/// own writes.
abstract interface class BackupRevisionRecorder {
  Future<void> recordCommittedMutation();
}

final class DriftBackupRevisionRecorder implements BackupRevisionRecorder {
  static const _id = 1;

  final SqliteDatabase _database;

  const DriftBackupRevisionRecorder(this._database);

  @override
  Future<void> recordCommittedMutation() async {
    await _database
        .into(_database.walletBackupStates)
        .insert(
          WalletBackupStatesCompanion.insert(id: const Value(_id)),
          mode: InsertMode.insertOrIgnore,
        );
    await _database.customStatement(
      'UPDATE wallet_backup_states SET local_revision = local_revision + 1 '
      'WHERE id = ?',
      [_id],
    );
  }
}

/// Used where a caller has no backup state to report to, such as a test that
/// exercises an owning repository on its own.
final class NoBackupRevisionRecorder implements BackupRevisionRecorder {
  const NoBackupRevisionRecorder();

  @override
  Future<void> recordCommittedMutation() async {}
}
