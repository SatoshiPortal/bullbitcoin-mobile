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
export 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_request.dart'
    show
        KeychainManifestReservedDerivationRequest,
        KeychainManifestWalletMaterializationRequest;

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_import.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_request.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_entry_usecase.dart';

class KeychainManifestFacade {
  static const _manifestFileCodec = KeychainManifestFileCodec();

  final RecordKeychainManifestEntryUsecase _recordEntry;
  final BuildKeychainManifestFileUsecase _buildManifestFile;
  final ParseKeychainManifestFileUsecase _parseManifestFile;

  KeychainManifestFacade({
    required this._recordEntry,
    required this._buildManifestFile,
    required this._parseManifestFile,
  });

  Future<void> recordReservedDerivation(
    KeychainManifestReservedDerivationRequest request, {
    DateTime? now,
  }) async {
    try {
      await _recordEntry.execute(request, now: now);
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
