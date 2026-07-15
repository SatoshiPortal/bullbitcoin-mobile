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

import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_request.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/record_keychain_manifest_entry_usecase.dart';

class KeychainManifestFacade {
  final RecordKeychainManifestEntryUsecase _recordEntry;

  KeychainManifestFacade({required this._recordEntry});

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
}
