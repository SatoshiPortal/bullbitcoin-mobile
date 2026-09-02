import 'package:bb_mobile/core/storage/backup_revision_recorder.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

final class DriftWalletBackupStateRepository
    implements WalletBackupStateRepository {
  static const _id = 1;

  final SqliteDatabase _database;
  final BackupRevisionRecorder _revisions;

  DriftWalletBackupStateRepository(this._database)
    : _revisions = DriftBackupRevisionRecorder(_database);

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
        final current = await _current();
        if (!enabled || current.enabled) {
          await _update(WalletBackupStatesCompanion(enabled: Value(enabled)));
          return;
        }
        // Turning automatic backup on is itself a reason to publish, so the
        // first pass has something to acknowledge.
        await _update(const WalletBackupStatesCompanion(enabled: Value(true)));
        await _revisions.recordCommittedMutation();
      });
    });
  }

  @override
  @useResult
  Future<Result<int, WalletBackupFailure>> recordLocalMutation() {
    return _read('record local mutation', () async {
      return _database.transaction(() async {
        await _ensureRow();
        await _revisions.recordCommittedMutation();
        return (await _current()).localRevision;
      });
    });
  }

  @override
  @useResult
  Future<Result<void, WalletBackupFailure>> recordPublication({
    required int publishedRevision,
    required int succeededAt,
    required WalletBackupRemoteCheckpoint checkpoint,
  }) {
    if (publishedRevision < 0) {
      throw ArgumentError.value(
        publishedRevision,
        'publishedRevision',
        'published revision must be non-negative',
      );
    }
    if (succeededAt < 0) {
      throw ArgumentError.value(
        succeededAt,
        'succeededAt',
        'wallet backup success timestamp must be non-negative',
      );
    }
    return _write('record publication', () async {
      await _database.transaction(() async {
        final current = await _current();
        if (publishedRevision > current.localRevision) {
          throw StateError(
            'published wallet backup revision exceeds the local revision',
          );
        }
        await _update(
          WalletBackupStatesCompanion(
            uploadedRevision: Value(
              publishedRevision > current.uploadedRevision
                  ? publishedRevision
                  : current.uploadedRevision,
            ),
            lastSucceededAt: Value(succeededAt),
            unsupportedVersion: const Value(null),
            remoteGeneration: Value(checkpoint.generation),
            remoteEtag: Value(checkpoint.etag),
            remoteCiphertextHash: Value(checkpoint.ciphertextSha256),
          ),
        );
      });
    });
  }

  @override
  @useResult
  Future<Result<void, WalletBackupFailure>> blockUnsupportedVersion(
    int version,
  ) {
    if (version <= WalletBackupSnapshot.currentVersion) {
      throw ArgumentError.value(
        version,
        'version',
        'blocked wallet backup version must be newer than this client',
      );
    }
    return _write('block unsupported version', () async {
      await _ensureRow();
      await _update(
        WalletBackupStatesCompanion(unsupportedVersion: Value(version)),
      );
    });
  }

  @override
  @useResult
  Future<Result<void, WalletBackupFailure>> setRecoveryState(
    WalletBackupRecoveryState state,
  ) {
    return _write('set recovery state', () async {
      await _ensureRow();
      await _update(
        WalletBackupStatesCompanion(recoveryState: Value(state.name)),
      );
    });
  }

  @override
  @useResult
  Future<Result<void, WalletBackupFailure>> saveRemoteCheckpoint(
    WalletBackupRemoteCheckpoint? checkpoint,
  ) {
    return _write('save remote checkpoint', () async {
      await _ensureRow();
      await _update(
        WalletBackupStatesCompanion(
          remoteGeneration: Value(checkpoint?.generation),
          remoteEtag: Value(checkpoint?.etag),
          remoteCiphertextHash: Value(checkpoint?.ciphertextSha256),
        ),
      );
    });
  }

  @override
  @useResult
  Future<Result<void, WalletBackupFailure>> clearRemoteCheckpoint() {
    return _write('clear remote checkpoint', () async {
      await _ensureRow();
      await _update(
        const WalletBackupStatesCompanion(
          lastSucceededAt: Value(null),
          lastRecoveryStatus: Value(null),
          unsupportedVersion: Value(null),
          recoveryState: Value('idle'),
          remoteGeneration: Value(null),
          remoteEtag: Value(null),
          remoteCiphertextHash: Value(null),
        ),
      );
    });
  }

  @override
  @useResult
  Future<Result<void, WalletBackupFailure>> saveRecoveryOutcome(
    WalletBackupRecoveryStatus status,
  ) => _write('save recovery outcome', () async {
    await _ensureRow();
    await _update(
      WalletBackupStatesCompanion(lastRecoveryStatus: Value(status.name)),
    );
  });

  @override
  @useResult
  Future<Result<void, WalletBackupFailure>> setServerUrl(String? serverUrl) {
    return _write('set server URL', () async {
      await _database.transaction(() async {
        final current = await _current();
        if (current.serverUrl == serverUrl) return;
        await _update(
          WalletBackupStatesCompanion(
            serverUrl: Value(serverUrl),
            lastSucceededAt: const Value(null),
            lastRecoveryStatus: const Value(null),
            unsupportedVersion: const Value(null),
            recoveryState: const Value('idle'),
            remoteGeneration: const Value(null),
            remoteEtag: const Value(null),
            remoteCiphertextHash: const Value(null),
          ),
        );
        // Another origin holds nothing this installation has published, so
        // everything local is unacknowledged again.
        await _revisions.recordCommittedMutation();
      });
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

  Future<WalletBackupStateRow> _current() async {
    await _ensureRow();
    return (_database.select(
      _database.walletBackupStates,
    )..where((row) => row.id.equals(_id))).getSingle();
  }

  Future<void> _update(WalletBackupStatesCompanion values) => (_database.update(
    _database.walletBackupStates,
  )..where((row) => row.id.equals(_id))).write(values);

  WalletBackupState _map(WalletBackupStateRow row) {
    return WalletBackupState(
      enabled: row.enabled,
      localRevision: row.localRevision,
      uploadedRevision: row.uploadedRevision > row.localRevision
          ? row.localRevision
          : row.uploadedRevision,
      lastSucceededAt: row.lastSucceededAt,
      unsupportedVersion: row.unsupportedVersion,
      recoveryState: _recoveryState(row.recoveryState),
      lastRecoveryStatus: WalletBackupRecoveryStatus.values
          .where((value) => value.name == row.lastRecoveryStatus)
          .firstOrNull,
      customServerUrl: row.serverUrl,
      remoteCheckpoint: _checkpoint(row),
    );
  }

  /// An unreadable fence value is read as needing attention rather than as
  /// idle, so a corrupt row can never release publication on its own.
  WalletBackupRecoveryState _recoveryState(String stored) =>
      WalletBackupRecoveryState.values
          .where((value) => value.name == stored)
          .firstOrNull ??
      WalletBackupRecoveryState.needsAttention;

  /// A checkpoint is trusted only when the generation and ETag agree; a torn
  /// pair is read as no checkpoint, so publication falls back to a fetch.
  WalletBackupRemoteCheckpoint? _checkpoint(WalletBackupStateRow row) {
    final generation = row.remoteGeneration;
    final etag = row.remoteEtag;
    if (generation == null || etag == null) return null;
    try {
      return WalletBackupRemoteCheckpoint(
        generation: generation,
        etag: etag,
        ciphertextSha256: row.remoteCiphertextHash,
      );
    } on ArgumentError catch (error, trace) {
      log.warning(
        'Discarding an invalid stored wallet backup checkpoint',
        error: error.runtimeType,
        trace: trace,
      );
      return null;
    }
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
