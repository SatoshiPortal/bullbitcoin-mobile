import 'dart:typed_data';

import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file_comparison.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/apply_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:primitives/primitives.dart';

typedef ApplyWalletBackupFileImport =
    Future<WalletBackupRecoveryResult> Function({
      required Result<WalletBackupSnapshot?, WalletBackupFailure> snapshot,
      DateTime? deadline,
    });
typedef SettleWalletBackupFence =
    Future<WalletBackupRecoveryResult> Function(
      WalletBackupRecoveryResult result, {
      required WalletBackupRecoveryState? fence,
    });
typedef DecodeWalletBackupFile =
    Future<Result<WalletBackupSnapshot, WalletBackupFailure>> Function(
      Uint8List bytes,
    );
typedef StoreSelectedWalletBackup =
    Future<Result<void, WalletBackupFailure>> Function({
      required WalletBackupSnapshot selected,
      required WalletBackupRemoteCheckpoint? current,
    });

/// File import: decode the file into the same typed snapshot remote recovery
/// produces, check that the comparison the user acted on is still current, and
/// delegate the apply to the shared fenced path (spec F21, 19.8).
///
/// Unlike remote recovery, applying is only half the job: when automatic
/// backup is on, the selected snapshot also has to replace the remote head.
/// This use case therefore settles the fence itself once it knows whether both
/// halves succeeded.
final class RecoverWalletBackupFileUsecase {
  final DecodeWalletBackupFile _decode;
  final ApplyWalletBackupFileImport _apply;
  final SettleWalletBackupFence _settle;
  final Future<Result<WalletBackupState, WalletBackupFailure>> Function()
  _getState;
  final Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> Function()
  _fetchRemote;
  final StoreSelectedWalletBackup _storeSelected;
  final DateTime Function() _nowUtc;

  const RecoverWalletBackupFileUsecase(
    this._decode,
    this._apply,
    this._settle,
    this._getState,
    this._fetchRemote,
    this._storeSelected, {
    this._nowUtc = _systemNowUtc,
  });

  Future<WalletBackupRecoveryResult> execute({
    required Uint8List fileBytes,
    required WalletBackupImportComparison comparison,
    required WalletBackupImportSource source,
  }) async {
    final bytes = switch (source) {
      WalletBackupImportSource.file => fileBytes,
      WalletBackupImportSource.server => comparison.copyServerCiphertextBytes(),
    };
    // Nothing has been touched yet, so a file this client cannot even read is
    // reported as it stands rather than recorded as a recovery outcome.
    if (bytes == null) return _status(WalletBackupRecoveryStatus.invalid);

    final WalletBackupSnapshot selected;
    switch (await _decode(bytes)) {
      case Ok(:final value):
        selected = value;
      case Err(:final failure):
        return WalletBackupRecoveryResult.fromFailure(failure);
    }

    return _recover(
      selected: selected,
      comparison: comparison,
      source: source,
      deadline: _nowUtc().add(ApplyBackupSnapshotUsecase.defaultBudget),
    );
  }

  Future<WalletBackupRecoveryResult> _recover({
    required WalletBackupSnapshot selected,
    required WalletBackupImportComparison comparison,
    required WalletBackupImportSource source,
    required DateTime deadline,
  }) async {
    final WalletBackupState state;
    switch (await _getState()) {
      case Ok(:final value):
        state = value;
      case Err(:final failure):
        return _settleNeedsNothing(
          WalletBackupRecoveryResult.fromFailure(failure),
        );
    }

    WalletBackupRemoteHead? comparedHead;
    var recoveringOffline = false;
    final requiresRemoteFreshness =
        state.enabled || source == WalletBackupImportSource.server;
    if (requiresRemoteFreshness) {
      switch (await _fetchRemote()) {
        case Ok(:final value):
          if (comparison.comparedServerGeneration == null ||
              !_matchesComparison(value, comparison)) {
            return _settleNeedsNothing(
              _status(WalletBackupRecoveryStatus.comparisonStale),
            );
          }
          comparedHead = value;
        case Err(failure: WalletBackupRemoteUnavailableFailure())
            when source == WalletBackupImportSource.file &&
                comparison.situation ==
                    WalletBackupImportSituation.serverUnavailable:
          recoveringOffline = true;
        case Err(failure: WalletBackupRemoteUnavailableFailure()):
          return _settleNeedsNothing(
            _status(WalletBackupRecoveryStatus.unavailable),
          );
        case Err(:final failure):
          return _settleNeedsNothing(
            WalletBackupRecoveryResult.fromFailure(failure),
          );
      }
    }

    final applied = await _apply(snapshot: Ok(selected), deadline: deadline);
    if (applied.status != WalletBackupRecoveryStatus.restored &&
        applied.status != WalletBackupRecoveryStatus.partiallyRestored) {
      return _settleAttention(applied);
    }

    if (applied.status == WalletBackupRecoveryStatus.partiallyRestored) {
      return state.enabled ? _settleAttention(applied) : _settleIdle(applied);
    }
    if (recoveringOffline) return _settleAttention(applied);
    if (!state.enabled ||
        comparison.situation ==
            WalletBackupImportSituation.automaticBackupDisabled) {
      return _settleIdle(applied);
    }
    if (source == WalletBackupImportSource.server) {
      switch (await _fetchRemote()) {
        case Ok(:final value) when _matchesComparison(value, comparison):
          return _settleIdle(applied);
        case Ok():
          return _settleAttention(
            _sameCounts(applied, WalletBackupRecoveryStatus.comparisonStale),
          );
        case Err(failure: WalletBackupRemoteUnavailableFailure()):
          return _settleAttention(applied);
        case Err(:final failure):
          return _settleAttention(
            _sameCounts(
              applied,
              WalletBackupRecoveryResult.statusForFailure(failure),
            ),
          );
      }
    }

    switch (await _storeSelected(
      selected: selected,
      current: comparedHead!.checkpoint,
    )) {
      case Ok():
        return _settleIdle(applied);
      case Err(failure: WalletBackupHeadConflictFailure()):
        return _settleAttention(
          _sameCounts(applied, WalletBackupRecoveryStatus.comparisonStale),
        );
      case Err(failure: WalletBackupRemoteUnavailableFailure()):
        return _settleAttention(applied);
      case Err(:final failure):
        return _settleAttention(
          _sameCounts(
            applied,
            WalletBackupRecoveryResult.statusForFailure(failure),
          ),
        );
    }
  }

  bool _matchesComparison(
    WalletBackupRemoteHead head,
    WalletBackupImportComparison comparison,
  ) =>
      head.generation == comparison.comparedServerGeneration &&
      head.etag == comparison.comparedServerEtag;

  Future<WalletBackupRecoveryResult> _settleIdle(
    WalletBackupRecoveryResult result,
  ) => _settle(result, fence: WalletBackupRecoveryState.idle);

  Future<WalletBackupRecoveryResult> _settleAttention(
    WalletBackupRecoveryResult result,
  ) => _settle(result, fence: WalletBackupRecoveryState.needsAttention);

  /// Nothing was applied, so the fence stays where it already was and only the
  /// outcome is recorded.
  Future<WalletBackupRecoveryResult> _settleNeedsNothing(
    WalletBackupRecoveryResult result,
  ) => _settle(result, fence: null);
}

WalletBackupRecoveryResult _status(WalletBackupRecoveryStatus status) =>
    WalletBackupRecoveryResult(status: status);

WalletBackupRecoveryResult _sameCounts(
  WalletBackupRecoveryResult applied,
  WalletBackupRecoveryStatus status,
) => WalletBackupRecoveryResult(
  status: status,
  restoredCount: applied.restoredCount,
  failedCount: applied.failedCount,
);

DateTime _systemNowUtc() => DateTime.now().toUtc();
