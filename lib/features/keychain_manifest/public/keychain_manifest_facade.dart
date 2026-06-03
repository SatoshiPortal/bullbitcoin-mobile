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

import 'package:bb_mobile/features/keychain_manifest/domain/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_file_codec.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_request.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/record_keychain_manifest_entry_usecase.dart';

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
    KeychainManifestFileRequest request, {
    DateTime? now,
  }) async {
    try {
      final manifestFile = await _buildManifestFile.execute(
        BuildKeychainManifestFileCommand(
          parentFingerprint: request.parentFingerprint,
        ),
        now: now,
      );
      return KeychainManifestFilePayload._(
        payload: const KeychainManifestFileCodec().encode(manifestFile),
      );
    } catch (e) {
      throw KeychainManifestException.fromInternal(e);
    }
  }
}

class KeychainManifestFileRequest {
  final String parentFingerprint;

  const KeychainManifestFileRequest({required this.parentFingerprint});
}

class KeychainManifestFilePayload {
  final String payload;

  const KeychainManifestFilePayload._({required this.payload});
}
