export 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart'
    show
        KeychainManifestDuplicateException,
        KeychainManifestEntryConflictException,
        KeychainManifestException,
        KeychainManifestExceptionType,
        KeychainManifestGenericException,
        KeychainManifestInvalidEntryException,
        KeychainManifestReservationMismatchException;
export 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_request.dart'
    show
        KeychainManifestReservedDerivationRequest,
        KeychainManifestWalletMaterializationRequest;

import 'dart:convert';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_request.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_entry_usecase.dart';

class KeychainManifestFacade {
  final RecordKeychainManifestEntryUsecase _recordEntry;
  final BuildKeychainManifestFileUsecase _buildManifestFile;

  KeychainManifestFacade({
    required this._recordEntry,
    required this._buildManifestFile,
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
        payload: const _KeychainManifestFileEncoder().encode(manifestFile),
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

class _KeychainManifestFileEncoder {
  const _KeychainManifestFileEncoder();

  String encode(KeychainManifestFile manifestFile) {
    return jsonEncode(_manifestToJson(manifestFile));
  }

  Map<String, Object?> _manifestToJson(KeychainManifestFile manifestFile) {
    return {
      'version': manifestFile.version,
      'parentFingerprint': manifestFile.parentFingerprint,
      'generatedAt': manifestFile.generatedAt,
      'inventoryUpdatedAt': manifestFile.inventoryUpdatedAt,
      'entryCount': manifestFile.entryCount,
      'materializationCount': manifestFile.materializationCount,
      'entries': manifestFile.entries.map(_entryToJson).toList(growable: false),
    };
  }

  Map<String, Object?> _entryToJson(KeychainManifestFileEntry entry) {
    return {
      'entryId': entry.entryId,
      'bip85DerivationPath': entry.bip85DerivationPath,
      'reservationId': entry.reservationId,
      'entryType': entry.entryType,
      'ownerFeature': entry.ownerFeature,
      'bip85Application': entry.bip85Application,
      'bip85Index': entry.bip85Index,
      'createdAt': entry.createdAt,
      'updatedAt': entry.updatedAt,
      'materializations': entry.materializations
          .map(_materializationToJson)
          .toList(growable: false),
    };
  }

  Map<String, Object?> _materializationToJson(
    KeychainManifestFileWalletMaterialization materialization,
  ) {
    return {
      'type': KeychainManifestFileWalletMaterialization.type,
      'walletId': materialization.walletId,
      'childSeedFingerprint': materialization.childSeedFingerprint,
      'network': materialization.network,
      'scriptType': materialization.scriptType,
      'createdAt': materialization.createdAt,
      'updatedAt': materialization.updatedAt,
    };
  }
}
