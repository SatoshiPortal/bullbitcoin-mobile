import 'dart:async';

export 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart'
    show
        KeychainManifestDuplicateException,
        KeychainManifestEntryConflictException,
        KeychainManifestException,
        KeychainManifestExceptionType,
        KeychainManifestFileParseException,
        KeychainManifestFileParseFailureReason,
        KeychainManifestGenericException,
        KeychainManifestInvalidEntryException,
        KeychainManifestReservationMismatchException,
        KeychainManifestUnsupportedVersionException;
export 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_import.dart'
    show
        KeychainManifestImportPlan,
        KeychainManifestImportEntryIntent,
        KeychainManifestWalletMaterializationIntent;
export 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_state.dart'
    show KeychainManifestBackupState;
export 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_import.dart'
    show KeychainManifestRemoteImportResult, KeychainManifestRemoteImportStatus;
export 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_reservation_support.dart'
    show KeychainManifestReservationSupport;
export 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_request.dart'
    show
        KeychainManifestReservedDerivationRequest,
        KeychainManifestWalletMaterializationRequest;

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_import.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_state.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_import.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_request.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/delete_keychain_manifest_backup_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/get_keychain_manifest_backup_state_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/fetch_keychain_manifest_remote_import_plan_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/flush_keychain_manifest_backup_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_entry_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/set_keychain_manifest_backup_enabled_usecase.dart';

class KeychainManifestFacade {
  static const _manifestFileCodec = KeychainManifestFileCodec();

  final RecordKeychainManifestEntryUsecase _recordEntry;
  final BuildKeychainManifestFileUsecase _buildManifestFile;
  final ParseKeychainManifestFileUsecase _parseManifestFile;
  final GetKeychainManifestBackupStateUsecase _getBackupState;
  final SetKeychainManifestBackupEnabledUsecase _setBackupEnabled;
  final DeleteKeychainManifestBackupUsecase _deleteBackup;
  final FetchKeychainManifestRemoteImportPlanUsecase _fetchRemoteImportPlan;
  final FlushKeychainManifestBackupUsecase _flushBackup;

  KeychainManifestFacade({
    required this._recordEntry,
    required this._buildManifestFile,
    required this._parseManifestFile,
    required this._getBackupState,
    required this._setBackupEnabled,
    required this._deleteBackup,
    required this._fetchRemoteImportPlan,
    required this._flushBackup,
  });

  Future<KeychainManifestBackupState> getBackupState() =>
      _getBackupState.execute();

  Stream<KeychainManifestBackupState> watchBackupState() =>
      _getBackupState.watch();

  Future<void> setBackupEnabled(bool enabled) =>
      _setBackupEnabled.execute(enabled);

  Future<void> backupNow() => _flushBackup.execute();

  Future<void> deleteRemoteBackup({required bool confirmed}) =>
      _deleteBackup.execute(confirmed: confirmed);

  Future<KeychainManifestRemoteImportResult> fetchRemoteImportPlan() =>
      _fetchRemoteImportPlan.execute();

  Future<void> recordReservedDerivation(
    KeychainManifestReservedDerivationRequest request, {
    DateTime? now,
    bool scheduleBackup = true,
  }) => _recordReservedDerivation(
    request,
    now: now,
    flushAfterCommit: scheduleBackup,
  );

  /// Records inventory restored from a remote snapshot without publishing it.
  ///
  /// Recovery may reconstruct local wallets but must not turn that read into a
  /// remote write. The durable dirty revision remains available to a later
  /// normal retry when backup was already enabled independently.
  Future<void> recordRecoveredDerivation(
    KeychainManifestReservedDerivationRequest request, {
    DateTime? now,
  }) => _recordReservedDerivation(request, now: now, flushAfterCommit: false);

  Future<void> _recordReservedDerivation(
    KeychainManifestReservedDerivationRequest request, {
    required bool flushAfterCommit,
    DateTime? now,
  }) async {
    try {
      await _recordEntry.execute(request, now: now);
      if (!flushAfterCommit) return;
      unawaited(
        _flushBackup.execute().catchError((Object error, StackTrace stack) {
          log.warning(
            'Post-materialization keychain backup failed',
            error: error,
            trace: stack,
          );
        }),
      );
    } catch (e) {
      throw KeychainManifestException.fromInternal(e);
    }
  }

  Future<KeychainManifestFilePayload> buildManifestFilePayload(
    String parentFingerprint, {
    bool allowEmpty = false,
    DateTime? now,
  }) async {
    try {
      final manifestFile = await _buildManifestFile.execute(
        parentFingerprint,
        now: now,
      );

      if (manifestFile.entries.isEmpty && !allowEmpty) {
        throw KeychainManifestEmptyInventoryException();
      }
      return KeychainManifestFilePayload._(
        payload: _manifestFileCodec.encode(manifestFile),
        entryCount: manifestFile.entryCount,
        materializationCount: manifestFile.materializationCount,
        generatedAt: manifestFile.generatedAt,
        inventoryUpdatedAt: manifestFile.inventoryUpdatedAt,
      );
    } catch (e, stack) {
      if (e is! KeychainManifestException) {
        log.warning(
          'Keychain manifest file build failed',
          error: e,
          trace: stack,
        );
      }
      throw KeychainManifestException.fromInternal(e);
    }
  }

  /// Parses a serialized manifest file into an import plan.
  ///
  /// Throws a [KeychainManifestException]. Consumers MUST distinguish the
  /// unsupported-version case: [KeychainManifestExceptionType.unsupportedFileVersion]
  /// means the backup exists but was written by a newer app version and MUST be
  /// shown as "update the app", never as "no backup found" (KC-2). Use
  /// `toTranslated` for the user-facing copy.
  KeychainManifestImportPlan parseManifestFilePayload(
    String payload, {
    required String expectedParentFingerprint,
    bool allowEmpty = false,
  }) {
    try {
      return _parseManifestFile.execute(
        payload,
        expectedParentFingerprint: expectedParentFingerprint,
        allowEmpty: allowEmpty,
      );
    } catch (e, stack) {
      if (e is! KeychainManifestException) {
        log.warning(
          'Keychain manifest file parse failed',
          error: e,
          trace: stack,
        );
      }
      throw KeychainManifestException.fromInternal(e);
    }
  }
}

class KeychainManifestFilePayload {
  final String payload;
  final int entryCount;
  final int materializationCount;
  final int generatedAt;
  final int inventoryUpdatedAt;

  bool get isEmpty => entryCount == 0;

  const KeychainManifestFilePayload._({
    required this.payload,
    required this.entryCount,
    required this.materializationCount,
    required this.generatedAt,
    required this.inventoryUpdatedAt,
  });
}
