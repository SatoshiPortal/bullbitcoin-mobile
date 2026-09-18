import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:drift/drift.dart';

final class DriftWalletBackupStateRepository
    implements WalletBackupStateRepository {
  final SqliteDatabase _database;

  const DriftWalletBackupStateRepository(this._database);

  @override
  Stream<void> get changes => _database
      .tableUpdates(
        TableUpdateQuery.onAllTables([
          _database.walletBackupStates,
          _database.walletBackupControls,
        ]),
      )
      .map((_) {});

  @override
  Future<Result<WalletBackupState, WalletBackupFailure>> get(String identity) =>
      _transaction(() async => Ok(await _load(identity)));

  Future<WalletBackupState> _load(String identity) async {
    final row = await (_database.select(
      _database.walletBackupStates,
    )..where((row) => row.identity.equals(identity))).getSingleOrNull();
    final recovery = await (_database.select(
      _database.walletBackupControls,
    )..where((row) => row.id.equals(1))).getSingleOrNull();
    if (row != null &&
        ((row.generation == null) != (row.etag == null) ||
            (row.generation == null) != (row.ciphertextHash == null))) {
      throw const FormatException('Incomplete backup checkpoint');
    }
    return WalletBackupState(
      identity: identity,
      enabled: recovery?.enabled,
      checkpoint: row?.generation == null
          ? null
          : WalletBackupCheckpoint(
              generation: row!.generation!,
              etag: row.etag!,
              ciphertextHash: row.ciphertextHash!,
            ),
      confirmedContentHash: row?.confirmedContentHash,
      lastSuccessAt: row?.lastSuccessAt?.toUtc(),
      recoveryIncomplete: recovery?.incomplete ?? false,
    );
  }

  @override
  Future<Result<WalletBackupControl, WalletBackupFailure>> getControl() =>
      _transaction(() async {
        final row = await (_database.select(
          _database.walletBackupControls,
        )..where((row) => row.id.equals(1))).getSingleOrNull();
        return Ok(
          WalletBackupControl(
            enabled: row?.enabled,
            recoveryIncomplete: row?.incomplete ?? false,
          ),
        );
      });

  @override
  Future<Result<void, WalletBackupFailure>> setEnabled(bool enabled) =>
      _transaction(() async {
        await _database
            .into(_database.walletBackupControls)
            .insert(
              WalletBackupControlsCompanion.insert(
                id: const Value(1),
                enabled: Value(enabled),
              ),
              onConflict: DoUpdate(
                (_) => WalletBackupControlsCompanion(enabled: Value(enabled)),
              ),
            );
        return const Ok(null);
      });

  @override
  Future<Result<void, WalletBackupFailure>> setRecoveryIncomplete(
    bool incomplete,
  ) => _transaction(() async {
    await _database
        .into(_database.walletBackupControls)
        .insert(
          WalletBackupControlsCompanion.insert(
            id: const Value(1),
            incomplete: Value(incomplete),
          ),
          onConflict: DoUpdate(
            (_) => WalletBackupControlsCompanion(incomplete: Value(incomplete)),
          ),
        );
    return const Ok(null);
  });

  @override
  Future<Result<void, WalletBackupFailure>> recordPublication({
    required String identity,
    required String? expectedEtag,
    required WalletBackupCheckpoint checkpoint,
    required String contentHash,
    required DateTime succeededAt,
  }) => _transaction(() async {
    final current = await _load(identity);
    if (current.recoveryIncomplete) {
      return const Err(WalletBackupIncompleteFailure());
    }
    if (current.checkpoint?.etag != expectedEtag ||
        checkpoint.generation <= (current.checkpoint?.generation ?? 0)) {
      return const Err(WalletBackupChangedFailure());
    }
    WalletBackupState(
      identity: identity,
      checkpoint: checkpoint,
      confirmedContentHash: contentHash,
      lastSuccessAt: succeededAt,
    );
    await _database
        .into(_database.walletBackupStates)
        .insert(
          WalletBackupStatesCompanion.insert(
            identity: identity,
            generation: Value(checkpoint.generation),
            etag: Value(checkpoint.etag),
            ciphertextHash: Value(checkpoint.ciphertextHash),
            confirmedContentHash: Value(contentHash),
            lastSuccessAt: Value(succeededAt.toUtc()),
          ),
          onConflict: DoUpdate(
            (_) => WalletBackupStatesCompanion(
              generation: Value(checkpoint.generation),
              etag: Value(checkpoint.etag),
              ciphertextHash: Value(checkpoint.ciphertextHash),
              confirmedContentHash: Value(contentHash),
              lastSuccessAt: Value(succeededAt.toUtc()),
            ),
          ),
        );
    return const Ok(null);
  });

  @override
  Future<Result<void, WalletBackupFailure>> clearRemoteCheckpoint({
    required String identity,
    required String expectedEtag,
  }) => _transaction(() async {
    final current = await _load(identity);
    if (current.enabled == true || current.checkpoint?.etag != expectedEtag) {
      return const Err(WalletBackupChangedFailure());
    }
    await (_database.update(
      _database.walletBackupStates,
    )..where((row) => row.identity.equals(identity))).write(
      const WalletBackupStatesCompanion(
        generation: Value(null),
        etag: Value(null),
        ciphertextHash: Value(null),
        confirmedContentHash: Value(null),
        lastSuccessAt: Value(null),
      ),
    );
    return const Ok(null);
  });

  Future<Result<T, WalletBackupFailure>> _transaction<T>(
    Future<Result<T, WalletBackupFailure>> Function() action,
  ) async {
    try {
      return await _database.transaction(action);
    } on Exception {
      return const Err(WalletBackupStorageFailure());
    }
  }
}
