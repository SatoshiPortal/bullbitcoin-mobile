export 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_apply.dart';
export 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
export 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_publish_outcome.dart';
export 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_apply.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_publish_outcome.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_recovery_plan.dart'
    as internal;
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/delete_wallet_metadata_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/get_wallet_metadata_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/mark_wallet_metadata_backup_dirty_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/set_wallet_metadata_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_publication_guard.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/watchers/wallet_metadata_backup_coordinator.dart';
import 'package:meta/meta.dart';

typedef _FetchRecoveryPlan =
    Future<
      Result<internal.WalletMetadataRecoveryResult, WalletMetadataBackupFailure>
    >
    Function();
typedef _ApplyRecoveryPlan =
    Future<
      Result<WalletMetadataRecoveryApplyResult, WalletMetadataBackupFailure>
    >
    Function({
      required internal.WalletMetadataRecoveryPlan plan,
      required Set<String> createdWalletRefs,
    });
typedef _RecoverMetadata =
    Future<Result<WalletMetadataRecoveryResult, WalletMetadataBackupFailure>>
    Function(Set<String> createdWalletRefs);

enum WalletMetadataRecoveryStatus {
  recovered,
  partiallyRecovered,
  noSnapshotFound,
  remoteUnavailable,
  unsupportedNewerEnvelope,
}

final class WalletMetadataRecoveryResult {
  final WalletMetadataRecoveryStatus status;
  final WalletMetadataRecoveryApplyResult? applyResult;

  const WalletMetadataRecoveryResult._({
    required this.status,
    this.applyResult,
  });

  factory WalletMetadataRecoveryResult.applied(
    WalletMetadataRecoveryApplyResult result,
  ) {
    return WalletMetadataRecoveryResult._(
      status: result.publicationBlocked
          ? WalletMetadataRecoveryStatus.partiallyRecovered
          : WalletMetadataRecoveryStatus.recovered,
      applyResult: result,
    );
  }

  const WalletMetadataRecoveryResult.noSnapshotFound()
    : this._(status: WalletMetadataRecoveryStatus.noSnapshotFound);

  const WalletMetadataRecoveryResult.remoteUnavailable()
    : this._(status: WalletMetadataRecoveryStatus.remoteUnavailable);

  const WalletMetadataRecoveryResult.unsupportedNewerEnvelope()
    : this._(status: WalletMetadataRecoveryStatus.unsupportedNewerEnvelope);
}

abstract interface class WalletMetadataRecoverySession {
  bool get isClosed;

  @useResult
  Future<Result<WalletMetadataRecoveryResult, WalletMetadataBackupFailure>>
  recover({required Set<String> createdWalletRefs});

  void close();
}

final class _WalletMetadataRecoverySession
    implements WalletMetadataRecoverySession {
  WalletMetadataPublicationSuppression? _suppression;
  final _RecoverMetadata _recover;
  final WalletMetadataBackupFailure? _preflightFailure;
  Future<Result<WalletMetadataRecoveryResult, WalletMetadataBackupFailure>>?
  _inFlight;
  bool _closeRequested = false;

  _WalletMetadataRecoverySession(
    this._suppression,
    this._recover, {
    this._preflightFailure,
  });

  @override
  bool get isClosed => _closeRequested || _suppression == null;

  @override
  @useResult
  Future<Result<WalletMetadataRecoveryResult, WalletMetadataBackupFailure>>
  recover({required Set<String> createdWalletRefs}) async {
    if (isClosed || _inFlight != null) {
      return Future.value(const Err(WalletMetadataBackupEncodingFailure()));
    }
    final preflightFailure = _preflightFailure;
    if (preflightFailure != null) {
      return Err(preflightFailure);
    }
    final recovery = _recover(Set.unmodifiable(createdWalletRefs));
    _inFlight = recovery;
    try {
      return await recovery;
    } finally {
      if (identical(_inFlight, recovery)) _inFlight = null;
      if (_closeRequested) _releaseSuppression();
    }
  }

  @override
  void close() {
    _closeRequested = true;
    if (_inFlight == null) _releaseSuppression();
  }

  void _releaseSuppression() {
    _suppression?.close();
    _suppression = null;
  }
}

class WalletMetadataBackupFacade {
  final GetWalletMetadataBackupStateUsecase _getState;
  final SetWalletMetadataBackupEnabledUsecase _setEnabled;
  final MarkWalletMetadataBackupDirtyUsecase _markDirty;
  final DeleteWalletMetadataBackupUsecase _deleteRemote;
  final WalletMetadataBackupCoordinator _coordinator;
  final _FetchRecoveryPlan _fetchRecoveryPlan;
  final _ApplyRecoveryPlan _applyRecoveryPlan;

  const WalletMetadataBackupFacade(
    this._getState,
    this._setEnabled,
    this._markDirty,
    this._deleteRemote,
    this._coordinator,
    this._fetchRecoveryPlan,
    this._applyRecoveryPlan,
  );

  @useResult
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  getState() => _getState.execute();

  @useResult
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  setEnabled(bool enabled) async {
    final result = enabled
        ? await _setEnabled.execute(true)
        : await _coordinator.suppressPublicationWhile(
            () => _setEnabled.execute(false),
          );
    if (result case Ok(value: WalletMetadataBackupState(enabled: true))) {
      _coordinator.scheduleFallbackRetry();
    }
    return result;
  }

  @useResult
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  markDirty() => _markDirty.execute();

  @useResult
  Future<Result<WalletMetadataPublishOutcome, WalletMetadataBackupFailure>>
  backupNow() => _coordinator.publishNow();

  @useResult
  Future<Result<void, WalletMetadataBackupFailure>> deleteRemoteBackup() {
    return _coordinator.suppressPublicationWhile(_deleteRemote.execute);
  }

  Future<void> retryPendingBackup() => _coordinator.retryBestEffort();

  Future<WalletMetadataRecoverySession> beginRecoverySession() async {
    final acquisition = await _coordinator.beginRecoverySession();
    return _WalletMetadataRecoverySession(
      acquisition.suppression,
      _recoverMetadata,
      preflightFailure: acquisition.failure,
    );
  }

  Future<Result<WalletMetadataRecoveryResult, WalletMetadataBackupFailure>>
  _recoverMetadata(Set<String> createdWalletRefs) async {
    final fetched = await _fetchRecoveryPlan();
    final internal.WalletMetadataRecoveryResult recovery;
    switch (fetched) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        recovery = value;
    }
    switch (recovery.status) {
      case internal.WalletMetadataRecoveryStatus.snapshot ||
          internal.WalletMetadataRecoveryStatus.snapshotWithUnsupportedMetadata:
        final plan = recovery.plan;
        if (plan == null) {
          return const Err(WalletMetadataBackupEncodingFailure());
        }
        final applied = await _applyRecoveryPlan(
          plan: plan,
          createdWalletRefs: createdWalletRefs,
        );
        return applied.map(WalletMetadataRecoveryResult.applied);
      case internal.WalletMetadataRecoveryStatus.noSnapshotFound:
        return const Ok(WalletMetadataRecoveryResult.noSnapshotFound());
      case internal.WalletMetadataRecoveryStatus.remoteUnavailable:
        return const Ok(WalletMetadataRecoveryResult.remoteUnavailable());
      case internal.WalletMetadataRecoveryStatus.unsupportedNewerEnvelope:
        return const Ok(
          WalletMetadataRecoveryResult.unsupportedNewerEnvelope(),
        );
    }
  }
}
