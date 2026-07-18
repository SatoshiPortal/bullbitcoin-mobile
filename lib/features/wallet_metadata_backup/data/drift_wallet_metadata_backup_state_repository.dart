import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';

final class DriftWalletMetadataBackupStateRepository
    implements WalletMetadataBackupStateRepository {
  static const int _rowId = 1;

  final SqliteDatabase _database;
  Future<void> _operationQueue = Future<void>.value();

  DriftWalletMetadataBackupStateRepository(this._database);

  @override
  @useResult
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  fetch() async {
    return _enqueue(_fetchNow);
  }

  @override
  @useResult
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>> update(
    WalletMetadataBackupStateUpdate update,
  ) async {
    return _enqueue(() => _updateNow(update));
  }

  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  _fetchNow() async {
    try {
      final current = _toEntity(await _readRow());
      final repaired = current.repairInvalidRecoveryState();
      if (!identical(current, repaired)) await _writeRow(repaired);
      return Ok(repaired);
    } on Exception catch (error, trace) {
      return _storageFailure('load', error, trace);
    }
  }

  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  _updateNow(WalletMetadataBackupStateUpdate update) async {
    try {
      final state = await _database.transaction(() async {
        final current = _toEntity(await _readRow());
        final repaired = current.repairInvalidRecoveryState();
        final next = update(repaired);
        if (!identical(current, next)) await _writeRow(next);
        return next;
      });
      return Ok(state);
    } on Exception catch (error, trace) {
      return _storageFailure('update', error, trace);
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final previous = _operationQueue;
    final queued = () async {
      await previous;
      return operation();
    }();
    _operationQueue = queued.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return queued;
  }

  Future<WalletMetadataBackupStateRow?> _readRow() {
    return (_database.select(
      _database.walletMetadataBackupStates,
    )..where((table) => table.id.equals(_rowId))).getSingleOrNull();
  }

  Future<void> _writeRow(WalletMetadataBackupState state) async {
    final head = state.verifiedHead;
    final blocked = state.unsupportedNewerEnvelope;
    final recovery = state.recoveryBlock;
    await _database
        .into(_database.walletMetadataBackupStates)
        .insertOnConflictUpdate(
          WalletMetadataBackupStateRow(
            id: _rowId,
            enabled: state.enabled,
            dirty: state.dirty,
            dirtyRevision: state.dirtyRevision,
            lastAttemptedAt: state.lastAttemptedAt,
            lastSucceededAt: state.lastSucceededAt,
            remoteGeneration: head?.remoteGeneration,
            remoteEtag: head?.remoteEtag,
            lastVerifiedSnapshotRevision: head?.snapshotRevision,
            lastVerifiedContentHash: head?.canonicalContentHash,
            lastVerifiedAt: head?.verifiedAt,
            blockedRemoteGeneration: blocked?.remoteGeneration,
            blockedRemoteEtag: blocked?.remoteEtag,
            blockedEnvelopeVersion: blocked?.envelopeVersion,
            blockedObservedAt: blocked?.observedAt,
            recoveryBlockedReason: recovery?.reason.name,
            recoveryBlockedRemoteGeneration: recovery?.remoteGeneration,
            recoveryBlockedRemoteEtag: recovery?.remoteEtag,
            recoveryBlockedSnapshotRevision: recovery?.snapshotRevision,
            recoveryBlockedObservedAt: recovery?.observedAt,
          ),
        );
  }

  WalletMetadataBackupState _toEntity(WalletMetadataBackupStateRow? row) {
    if (row == null) return WalletMetadataBackupState.initial;
    return WalletMetadataBackupState(
      enabled: row.enabled,
      dirty: row.dirty,
      dirtyRevision: row.dirtyRevision,
      lastAttemptedAt: row.lastAttemptedAt,
      lastSucceededAt: row.lastSucceededAt,
      verifiedHead: _verifiedHead(row),
      unsupportedNewerEnvelope: _unsupportedEnvelope(row),
      recoveryBlock: _recoveryBlock(row),
    );
  }

  WalletMetadataBackupVerifiedHead? _verifiedHead(
    WalletMetadataBackupStateRow row,
  ) {
    final values = [
      row.remoteGeneration,
      row.remoteEtag,
      row.lastVerifiedSnapshotRevision,
      row.lastVerifiedContentHash,
      row.lastVerifiedAt,
    ];
    if (values.every((value) => value == null)) return null;
    if (values.any((value) => value == null)) {
      throw const FormatException('stored Bullnym checkpoint is incomplete');
    }
    return WalletMetadataBackupVerifiedHead(
      remoteGeneration: row.remoteGeneration!,
      remoteEtag: row.remoteEtag!,
      snapshotRevision: row.lastVerifiedSnapshotRevision!,
      canonicalContentHash: row.lastVerifiedContentHash!,
      verifiedAt: row.lastVerifiedAt!,
    );
  }

  WalletMetadataBackupUnsupportedEnvelope? _unsupportedEnvelope(
    WalletMetadataBackupStateRow row,
  ) {
    final values = [
      row.blockedRemoteGeneration,
      row.blockedRemoteEtag,
      row.blockedEnvelopeVersion,
      row.blockedObservedAt,
    ];
    if (values.every((value) => value == null)) return null;
    if (values.any((value) => value == null)) {
      throw const FormatException('stored unsupported envelope is incomplete');
    }
    return WalletMetadataBackupUnsupportedEnvelope(
      remoteGeneration: row.blockedRemoteGeneration!,
      remoteEtag: row.blockedRemoteEtag!,
      envelopeVersion: row.blockedEnvelopeVersion!,
      observedAt: row.blockedObservedAt!,
    );
  }

  WalletMetadataBackupRecoveryBlock? _recoveryBlock(
    WalletMetadataBackupStateRow row,
  ) {
    final values = [
      row.recoveryBlockedReason,
      row.recoveryBlockedRemoteGeneration,
      row.recoveryBlockedRemoteEtag,
      row.recoveryBlockedSnapshotRevision,
      row.recoveryBlockedObservedAt,
    ];
    if (values.every((value) => value == null)) return null;
    if (values.any((value) => value == null)) {
      throw const FormatException('stored recovery block is incomplete');
    }
    final reason = WalletMetadataRecoveryBlockReason.values
        .where((value) => value.name == row.recoveryBlockedReason)
        .firstOrNull;
    if (reason == null) {
      throw const FormatException('stored recovery block reason is invalid');
    }
    return WalletMetadataBackupRecoveryBlock(
      reason: reason,
      remoteGeneration: row.recoveryBlockedRemoteGeneration!,
      remoteEtag: row.recoveryBlockedRemoteEtag!,
      snapshotRevision: row.recoveryBlockedSnapshotRevision!,
      observedAt: row.recoveryBlockedObservedAt!,
    );
  }

  Result<WalletMetadataBackupState, WalletMetadataBackupFailure>
  _storageFailure(String operation, Object error, StackTrace trace) {
    log.warning(
      'Could not $operation wallet metadata backup state',
      error: error.runtimeType,
      trace: trace,
    );
    return Err(
      WalletMetadataBackupStorageFailure(error.runtimeType.toString()),
    );
  }
}
