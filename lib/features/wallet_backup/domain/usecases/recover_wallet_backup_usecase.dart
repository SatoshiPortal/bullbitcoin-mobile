import 'dart:async';

import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_manifest_import.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_identity.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery_outcome.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_recovery_outcome_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/fetch_wallet_backup_manifest_import_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/fetch_wallet_backup_remote_identity_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/restore_wallet_backup_manifest_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/set_wallet_backup_recovery_blocked_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_definitions_section.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_apply.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_section.dart';
import 'package:bb_mobile/features/wallet_backup/watchers/wallet_backup_coordinator.dart';
import 'package:primitives/primitives.dart';

final class RecoverWalletBackupUsecase {
  static const defaultBudget = Duration(seconds: 60);

  final FetchWalletBackupManifestImportUsecase _fetchImport;
  final FetchWalletBackupRemoteIdentityUsecase _fetchIdentity;
  final RestoreWalletBackupManifestUsecase _restoreManifest;
  final SetWalletBackupRecoveryBlockedUsecase _setBlocked;
  final WalletBackupCoordinator _coordinator;
  final WalletBackupRecoveryOutcomeRepository _outcomes;
  final WalletDefinitionsBackup? _definitions;
  final WalletMetadataBackup? _metadata;
  final DateTime Function() _nowUtc;
  final Duration _budget;

  const RecoverWalletBackupUsecase(
    this._definitions, {
    required this._fetchImport,
    required this._fetchIdentity,
    required this._restoreManifest,
    required this._setBlocked,
    required this._coordinator,
    required this._outcomes,
    this._metadata,
    this._nowUtc = _systemNowUtc,
    this._budget = defaultBudget,
  });

  Future<WalletBackupRecoveryResult> execute({
    Set<String> defaultCreatedWalletIds = const {},
  }) async {
    final result = await _recoverWithinBudget(
      defaultCreatedWalletIds: defaultCreatedWalletIds,
    );
    final saved = await _outcomes.save(
      WalletBackupRecoveryOutcome(
        status: result.status,
        completedAt: _nowUtc().millisecondsSinceEpoch ~/ 1000,
        restoredCount: result.restoredCount,
        failedCount: result.failedCount,
      ),
    );
    return switch (saved) {
      Err() => WalletBackupRecoveryResult(
        status: WalletBackupRecoveryStatus.localFailure,
        restoredCount: result.restoredCount,
        failedCount: result.failedCount,
        createdWalletIds: result.createdWalletIds,
      ),
      Ok() => result,
    };
  }

  Future<WalletBackupRecoveryResult> _recoverWithinBudget({
    required Set<String> defaultCreatedWalletIds,
  }) async {
    try {
      return await _recover(defaultCreatedWalletIds: defaultCreatedWalletIds);
    } on TimeoutException {
      return _result(WalletBackupRecoveryStatus.timedOut);
    }
  }

  Future<WalletBackupRecoveryResult> _recover({
    required Set<String> defaultCreatedWalletIds,
  }) async {
    final deadline = _nowUtc().add(_budget);
    final lease = await _coordinator.beginRecoveryLease(timeout: _budget);
    try {
      if (await _setBlocked.execute(true) case Err()) {
        return _result(WalletBackupRecoveryStatus.localFailure);
      }

      final WalletBackupRemoteIdentity initialIdentity;
      switch (await _fetchIdentity.execute()) {
        case Ok(:final value):
          initialIdentity = value;
        case Err(:final failure):
          return _result(_failureStatus(failure));
      }

      final WalletBackupManifestImport? manifestImport;
      switch (await _fetchImport.execute()) {
        case Ok(:final value):
          manifestImport = value;
        case Err(:final failure):
          return _result(_failureStatus(failure));
      }
      if (manifestImport == null) {
        final unblocked = await _setBlocked.execute(false);
        if (unblocked case Err()) {
          return _result(WalletBackupRecoveryStatus.localFailure);
        }
        return _result(WalletBackupRecoveryStatus.noBackup);
      }
      if (_expired(deadline)) {
        return _result(WalletBackupRecoveryStatus.timedOut);
      }

      final restored = await _restoreManifest.execute(
        manifestImport.plan,
        deadline: deadline,
      );
      if (_expired(deadline)) {
        return _result(WalletBackupRecoveryStatus.timedOut, restored: restored);
      }

      WalletDefinitionsRecoveryResult? definitionsRestored;
      final definitionsPayload = manifestImport.definitionsPayload;
      if (definitionsPayload != null && _definitions != null) {
        switch (await _definitions.recover(
          payload: definitionsPayload,
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
      final metadataPayload = manifestImport.metadataPayload;
      if (metadataPayload != null && _metadata != null) {
        final metadataResult = await _metadata.recover(
          payload: metadataPayload,
          createdWalletRefs: {
            ...defaultCreatedWalletIds,
            ...restored.createdWalletIds,
            ...?definitionsRestored?.createdWalletRefs,
          },
          deadline: deadline,
        );
        metadataComplete = switch (metadataResult) {
          Ok(value: final value) =>
            value.status == WalletMetadataRecoveryApplyStatus.complete,
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

      final WalletBackupRemoteIdentity finalIdentity;
      switch (await _fetchIdentity.execute()) {
        case Ok(:final value):
          finalIdentity = value;
        case Err(:final failure):
          return _result(
            _failureStatus(failure),
            restored: restored,
            definitions: definitionsRestored,
          );
      }
      if (finalIdentity != initialIdentity) {
        return _result(
          WalletBackupRecoveryStatus.conflict,
          restored: restored,
          definitions: definitionsRestored,
        );
      }

      final complete =
          restored.failedCount == 0 &&
          (definitionsRestored?.failedCount ?? 0) == 0 &&
          metadataComplete;
      if (complete) {
        final unblocked = await _setBlocked.execute(false);
        if (unblocked case Err()) {
          return _result(
            WalletBackupRecoveryStatus.localFailure,
            restored: restored,
            definitions: definitionsRestored,
          );
        }
      }
      return _result(
        complete
            ? WalletBackupRecoveryStatus.restored
            : WalletBackupRecoveryStatus.partiallyRestored,
        restored: restored,
        definitions: definitionsRestored,
      );
    } finally {
      lease.close();
    }
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
    createdWalletIds: [
      ...?restored?.createdWalletIds,
      ...?definitions?.createdWalletRefs,
    ],
  );

  bool _expired(DateTime deadline) => !_nowUtc().isBefore(deadline);
}

WalletBackupRecoveryStatus _failureStatus(WalletBackupFailure failure) =>
    switch (failure) {
      WalletBackupRemoteUnavailableFailure() =>
        WalletBackupRecoveryStatus.unavailable,
      WalletBackupUnsupportedEnvelopeVersionFailure() ||
      WalletBackupUnsupportedSectionFailure() =>
        WalletBackupRecoveryStatus.newerVersion,
      WalletBackupHeadConflictFailure() => WalletBackupRecoveryStatus.conflict,
      WalletBackupInvalidEnvelopeFailure() ||
      WalletBackupParentFingerprintMismatchFailure() ||
      WalletBackupEncryptionFailure() ||
      WalletBackupInvalidRemoteFailure() ||
      WalletBackupManifestFailure() => WalletBackupRecoveryStatus.invalid,
      WalletBackupDefinitionsFailure() => WalletBackupRecoveryStatus.invalid,
      _ => WalletBackupRecoveryStatus.localFailure,
    };

DateTime _systemNowUtc() => DateTime.now().toUtc();
