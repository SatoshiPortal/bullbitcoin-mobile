import 'dart:async';

import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/restore_wallet_backup_manifest_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_definitions_section.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_backup_failure.dart';
import 'package:primitives/primitives.dart';

typedef ValidateWalletBackupRecovery =
    Future<Result<bool, WalletBackupFailure>> Function();
typedef ValidateWalletMetadataSnapshot =
    Result<void, WalletMetadataBackupFailure> Function(
      WalletMetadataSnapshot snapshot,
    );
typedef RestoreWalletMetadataSnapshot =
    Future<Result<bool, WalletMetadataBackupFailure>> Function({
      required WalletMetadataSnapshot snapshot,
      required Set<String> createdWalletRefs,
      DateTime? deadline,
    });

/// The one path that writes a backup snapshot into local storage.
///
/// Remote recovery and file import both come through here, so there is a
/// single durable fence rather than one per entry point (spec F21, 19.7).
/// The fence is [WalletBackupState.recoveryState]: applying before the first
/// local write, then idle on a complete, revalidated apply, or needs-attention
/// on anything else. A process that dies mid-apply leaves applying behind,
/// which reads as needing attention and refuses publication until the user
/// resolves it.
///
/// Serialization is the job runner's business; nothing here takes a lock.
final class ApplyBackupSnapshotUsecase {
  static const defaultBudget = Duration(seconds: 60);

  final WalletBackupStateRepository _state;
  final WalletDefinitionsBackup _definitions;
  final RestoreWalletBackupManifestUsecase _restoreManifest;
  final ValidateWalletMetadataSnapshot _validateMetadata;
  final RestoreWalletMetadataSnapshot _restoreMetadata;
  final DateTime Function() _nowUtc;
  final Duration _budget;

  const ApplyBackupSnapshotUsecase(
    this._state,
    this._definitions, {
    required this._restoreManifest,
    required this._validateMetadata,
    required this._restoreMetadata,
    this._nowUtc = _systemNowUtc,
    this._budget = defaultBudget,
  });

  /// Applies [snapshot] under the durable fence.
  ///
  /// [revalidate] proves the remote object did not change while the apply was
  /// running. When [callerSettlesFence] is set the caller decides the final
  /// fence value and records the outcome, because for a file import the apply
  /// is only half of the operation.
  Future<WalletBackupRecoveryResult> execute({
    required Result<WalletBackupSnapshot?, WalletBackupFailure> snapshot,
    ValidateWalletBackupRecovery? revalidate,
    Set<String> defaultCreatedWalletIds = const {},
    bool callerSettlesFence = false,
    DateTime? deadline,
  }) async {
    final budget = deadline ?? _nowUtc().add(_budget);
    late WalletBackupRecoveryResult result;
    try {
      result = switch (snapshot) {
        Err(:final failure) => WalletBackupRecoveryResult.fromFailure(failure),
        Ok(:final value) => await _apply(
          snapshot: value,
          revalidate: revalidate,
          defaultCreatedWalletIds: defaultCreatedWalletIds,
          deadline: budget,
          settleFence: !callerSettlesFence,
        ),
      };
    } on TimeoutException {
      result = _result(WalletBackupRecoveryStatus.timedOut);
    }
    return callerSettlesFence ? result : _saveOutcome(result);
  }

  /// Records the outcome of a [callerSettlesFence] apply, and the fence value
  /// the caller reached once it knew whether the whole operation succeeded.
  ///
  /// A null [fence] leaves the fence untouched, which is what a caller that
  /// gave up before writing anything wants: it must not clear a block another
  /// operation raised.
  Future<WalletBackupRecoveryResult> settle(
    WalletBackupRecoveryResult result, {
    required WalletBackupRecoveryState? fence,
  }) async {
    if (fence != null) {
      if (await _state.setRecoveryState(fence) case Err()) {
        return _localFailure(result);
      }
    }
    return _saveOutcome(result);
  }

  Future<WalletBackupRecoveryResult> _apply({
    required WalletBackupSnapshot? snapshot,
    required ValidateWalletBackupRecovery? revalidate,
    required Set<String> defaultCreatedWalletIds,
    required DateTime deadline,
    required bool settleFence,
  }) async {
    if (snapshot != null) {
      if (_validateSections(snapshot) case Err(:final failure)) {
        return WalletBackupRecoveryResult.fromFailure(failure);
      }
    }
    // Applying a foreign snapshot invalidates whatever this installation
    // believed the remote head to be, so the next publication fetches it
    // afresh. Raising the fence first keeps that off the race with a
    // publication the runner may start the moment this job ends.
    if (await _state.setRecoveryState(WalletBackupRecoveryState.applying)
        case Err()) {
      return _result(WalletBackupRecoveryStatus.localFailure);
    }
    if (await _state.saveRemoteCheckpoint(null) case Err()) {
      return _result(WalletBackupRecoveryStatus.localFailure);
    }
    if (snapshot == null) {
      return settleFence
          ? _lower(_result(WalletBackupRecoveryStatus.noBackup))
          : _result(WalletBackupRecoveryStatus.noBackup);
    }
    if (_expired(deadline)) {
      return _result(WalletBackupRecoveryStatus.timedOut);
    }

    final restored = await _restoreManifest.execute(
      snapshot.recoveryManifest,
      deadline: deadline,
    );
    if (_expired(deadline)) {
      return _result(WalletBackupRecoveryStatus.timedOut, restored: restored);
    }

    WalletDefinitionsRecoveryResult? definitionsRestored;
    if (snapshot.externalWalletDefinitions.isNotEmpty) {
      switch (await _definitions.recover(
        definitions: snapshot.externalWalletDefinitions,
        deadline: deadline,
      )) {
        case Ok(:final value):
          definitionsRestored = value;
        case Err():
          return _result(
            WalletBackupRecoveryStatus.invalid,
            restored: restored,
          );
      }
    }
    if (_expired(deadline)) {
      return _result(
        WalletBackupRecoveryStatus.timedOut,
        restored: restored,
        definitions: definitionsRestored,
      );
    }

    var metadataComplete = true;
    if (snapshot.metadata case final metadata?) {
      final metadataResult = await _restoreMetadata(
        snapshot: metadata,
        createdWalletRefs: {
          ...defaultCreatedWalletIds,
          ...?definitionsRestored?.createdWalletRefs,
        },
        deadline: deadline,
      );
      metadataComplete = switch (metadataResult) {
        Ok(:final value) => value,
        Err() => false,
      };
    }
    if (_expired(deadline)) {
      return _result(
        WalletBackupRecoveryStatus.timedOut,
        restored: restored,
        definitions: definitionsRestored,
      );
    }

    if (revalidate != null) {
      switch (await revalidate()) {
        case Ok(value: true):
          break;
        case Ok():
          return _result(
            WalletBackupRecoveryStatus.conflict,
            restored: restored,
            definitions: definitionsRestored,
          );
        case Err(:final failure):
          return _result(
            WalletBackupRecoveryResult.statusForFailure(failure),
            restored: restored,
            definitions: definitionsRestored,
          );
      }
    }

    final complete =
        restored.failedCount == 0 &&
        (definitionsRestored?.failedCount ?? 0) == 0 &&
        metadataComplete;
    final result = _result(
      complete
          ? WalletBackupRecoveryStatus.restored
          : WalletBackupRecoveryStatus.partiallyRestored,
      restored: restored,
      definitions: definitionsRestored,
    );
    return complete && settleFence ? _lower(result) : result;
  }

  /// Lowers the fence after a complete apply. Anything short of complete keeps
  /// it raised, which [_saveOutcome] then turns into needs-attention.
  Future<WalletBackupRecoveryResult> _lower(
    WalletBackupRecoveryResult result,
  ) async =>
      switch (await _state.setRecoveryState(WalletBackupRecoveryState.idle)) {
        Ok() => result,
        Err() => _localFailure(result),
      };

  Future<WalletBackupRecoveryResult> _saveOutcome(
    WalletBackupRecoveryResult result,
  ) async {
    // An apply that got as far as raising the fence and then stopped must not
    // be left in applying: that value means a run is in progress, and no run
    // is.
    if (await _state.get() case Ok(
      value: WalletBackupState(
        recoveryState: WalletBackupRecoveryState.applying,
      ),
    )) {
      if (await _state.setRecoveryState(
            WalletBackupRecoveryState.needsAttention,
          )
          case Err()) {
        return _localFailure(result);
      }
    }
    return switch (await _state.saveRecoveryOutcome(result.status)) {
      Err() => _localFailure(result),
      Ok() => result,
    };
  }

  Result<void, WalletBackupFailure> _validateSections(
    WalletBackupSnapshot snapshot,
  ) {
    if (snapshot.metadata case final metadata?) {
      if (_validateMetadata(metadata) case Err(:final failure)) {
        return Err(WalletBackupManifestFailure(failure.runtimeType.toString()));
      }
    }
    return const Ok(null);
  }

  WalletBackupRecoveryResult _result(
    WalletBackupRecoveryStatus status, {
    WalletBackupManifestRestoreResult? restored,
    WalletDefinitionsRecoveryResult? definitions,
  }) => WalletBackupRecoveryResult(
    status: status,
    restoredCount:
        (restored?.restoredCount ?? 0) + (definitions?.restoredCount ?? 0),
    failedCount: (restored?.failedCount ?? 0) + (definitions?.failedCount ?? 0),
  );

  bool _expired(DateTime deadline) => !_nowUtc().isBefore(deadline);
}

WalletBackupRecoveryResult _localFailure(WalletBackupRecoveryResult result) =>
    WalletBackupRecoveryResult(
      status: WalletBackupRecoveryStatus.localFailure,
      restoredCount: result.restoredCount,
      failedCount: result.failedCount,
    );

DateTime _systemNowUtc() => DateTime.now().toUtc();
