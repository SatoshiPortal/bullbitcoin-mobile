import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_envelope.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

final class DriftWalletBackupStateRepository
    implements WalletBackupStateRepository {
  static const _id = 1;

  final SqliteDatabase _database;

  const DriftWalletBackupStateRepository(this._database);

  @override
  @useResult
  Future<Result<WalletBackupState, WalletBackupFailure>> get() {
    return _read('load', () async {
      await _ensureRow();
      final row = await (_database.select(
        _database.walletBackupStates,
      )..where((table) => table.id.equals(_id))).getSingle();
      return _map(row);
    });
  }

  @override
  @useResult
  Stream<Result<WalletBackupState, WalletBackupFailure>> watch() async* {
    try {
      await _ensureRow();
      final rows = (_database.select(
        _database.walletBackupStates,
      )..where((table) => table.id.equals(_id))).watchSingle();
      await for (final row in rows) {
        yield Ok(_map(row));
      }
    } on Exception catch (error, trace) {
      _logStorageFailure('watch', error, trace);
      yield Err(_storageFailure('watch', error));
    }
  }

  @override
  @useResult
  Future<Result<void, WalletBackupFailure>> setEnabled(bool enabled) {
    return _write('set enabled', () async {
      await _database.transaction(() async {
        await _ensureRow();
        final table = _database.walletBackupStates;
        final current = await (_database.select(
          table,
        )..where((row) => row.id.equals(_id))).getSingle();
        if (!enabled || current.enabled) {
          await (_database.update(table)..where((row) => row.id.equals(_id)))
              .write(WalletBackupStatesCompanion(enabled: Value(enabled)));
          return;
        }
        await (_database.update(
          table,
        )..where((row) => row.id.equals(_id))).write(
          WalletBackupStatesCompanion(
            enabled: const Value(true),
            dirty: const Value(true),
            dirtyRevision: Value(current.dirtyRevision + 1),
          ),
        );
      });
    });
  }

  @override
  @useResult
  Future<Result<void, WalletBackupFailure>> markDirty() {
    return _write('mark dirty', () async {
      await _database.transaction(() async {
        await _ensureRow();
        final table = _database.walletBackupStates;
        final current = await (_database.select(
          table,
        )..where((row) => row.id.equals(_id))).getSingle();
        await (_database.update(
          table,
        )..where((row) => row.id.equals(_id))).write(
          WalletBackupStatesCompanion(
            dirty: const Value(true),
            dirtyRevision: Value(current.dirtyRevision + 1),
          ),
        );
      });
    });
  }

  @override
  @useResult
  Future<Result<void, WalletBackupFailure>> recordAttempt(int attemptedAt) {
    if (attemptedAt < 0) {
      throw ArgumentError.value(
        attemptedAt,
        'attemptedAt',
        'wallet backup attempt timestamp must be non-negative',
      );
    }
    return _write('record attempt', () async {
      await _ensureRow();
      await (_database.update(
        _database.walletBackupStates,
      )..where((table) => table.id.equals(_id))).write(
        WalletBackupStatesCompanion(lastAttemptedAt: Value(attemptedAt)),
      );
    });
  }

  @override
  @useResult
  Future<Result<void, WalletBackupFailure>> recordSuccess({
    required int capturedDirtyRevision,
    required int succeededAt,
    required WalletBackupSyncResult syncResult,
  }) {
    if (capturedDirtyRevision < 0) {
      throw ArgumentError.value(
        capturedDirtyRevision,
        'capturedDirtyRevision',
        'captured dirty revision must be non-negative',
      );
    }
    if (succeededAt < 0) {
      throw ArgumentError.value(
        succeededAt,
        'succeededAt',
        'wallet backup success timestamp must be non-negative',
      );
    }
    return _write('record success', () async {
      await _database.transaction(() async {
        await _ensureRow();
        final table = _database.walletBackupStates;
        final current = await (_database.select(
          table,
        )..where((row) => row.id.equals(_id))).getSingle();
        if (capturedDirtyRevision > current.dirtyRevision) {
          throw StateError(
            'captured wallet backup revision exceeds durable revision',
          );
        }
        await (_database.update(
          table,
        )..where((row) => row.id.equals(_id))).write(
          WalletBackupStatesCompanion(
            lastSucceededAt: Value(succeededAt),
            remoteGeneration: Value(syncResult.checkpoint.generation),
            remoteEtag: Value(syncResult.checkpoint.etag),
            contentHash: Value(syncResult.contentHash),
            unsupportedVersion: const Value(null),
          ),
        );
        if (current.dirtyRevision == capturedDirtyRevision) {
          await (_database.update(table)..where((row) => row.id.equals(_id)))
              .write(const WalletBackupStatesCompanion(dirty: Value(false)));
        }
      });
    });
  }

  @override
  @useResult
  Future<Result<void, WalletBackupFailure>> blockUnsupportedVersion(
    int version,
  ) {
    if (version <= WalletBackupEnvelope.currentVersion) {
      throw ArgumentError.value(
        version,
        'version',
        'blocked wallet backup version must be newer than this client',
      );
    }
    return _write('block unsupported version', () async {
      await _ensureRow();
      await (_database.update(
        _database.walletBackupStates,
      )..where((table) => table.id.equals(_id))).write(
        WalletBackupStatesCompanion(unsupportedVersion: Value(version)),
      );
    });
  }

  @override
  @useResult
  Future<Result<void, WalletBackupFailure>> setRecoveryBlocked(bool blocked) {
    return _write('set recovery block', () async {
      await _ensureRow();
      await (_database.update(_database.walletBackupStates)
            ..where((table) => table.id.equals(_id)))
          .write(WalletBackupStatesCompanion(recoveryBlocked: Value(blocked)));
    });
  }

  @override
  @useResult
  Future<Result<void, WalletBackupFailure>> clearRemoteCheckpoint() {
    return _write('clear remote checkpoint', () async {
      await _ensureRow();
      await (_database.update(
        _database.walletBackupStates,
      )..where((table) => table.id.equals(_id))).write(
        const WalletBackupStatesCompanion(
          lastSucceededAt: Value(null),
          remoteGeneration: Value(0),
          remoteEtag: Value(null),
          contentHash: Value(null),
          unsupportedVersion: Value(null),
          recoveryBlocked: Value(false),
        ),
      );
    });
  }

  Future<void> _ensureRow() async {
    await _database
        .into(_database.walletBackupStates)
        .insert(
          WalletBackupStatesCompanion.insert(id: const Value(_id)),
          mode: InsertMode.insertOrIgnore,
        );
  }

  WalletBackupState _map(WalletBackupStateRow row) {
    return WalletBackupState(
      enabled: row.enabled,
      dirty: row.dirty,
      dirtyRevision: row.dirtyRevision,
      lastAttemptedAt: row.lastAttemptedAt,
      lastSucceededAt: row.lastSucceededAt,
      remoteGeneration: row.remoteGeneration,
      remoteEtag: row.remoteEtag,
      contentHash: row.contentHash,
      unsupportedVersion: row.unsupportedVersion,
      recoveryBlocked: row.recoveryBlocked,
    );
  }

  Future<Result<T, WalletBackupFailure>> _read<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    try {
      return Ok(await action());
    } on Exception catch (error, trace) {
      _logStorageFailure(operation, error, trace);
      return Err(_storageFailure(operation, error));
    }
  }

  Future<Result<void, WalletBackupFailure>> _write(
    String operation,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return const Ok(null);
    } on Exception catch (error, trace) {
      _logStorageFailure(operation, error, trace);
      return Err(_storageFailure(operation, error));
    }
  }
}

WalletBackupStorageFailure _storageFailure(String operation, Object error) =>
    WalletBackupStorageFailure('$operation failed: ${error.runtimeType}');

void _logStorageFailure(String operation, Object error, StackTrace trace) {
  log.warning(
    'Wallet backup state storage operation failed: $operation',
    error: error.runtimeType,
    trace: trace,
  );
}
