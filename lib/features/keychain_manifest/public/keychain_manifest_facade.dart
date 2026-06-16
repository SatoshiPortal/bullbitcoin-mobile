import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/application/application_errors.dart';
import 'package:bb_mobile/features/keychain_manifest/application/usecases/record_keychain_manifest_entry_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/domain_errors.dart';

class KeychainManifestFacade {
  final RecordKeychainManifestEntryUsecase _recordEntry;

  KeychainManifestFacade({required this._recordEntry});

  Future<void> recordReservedDerivation(
    KeychainManifestReservedDerivationRequest request, {
    DateTime? now,
  }) async {
    try {
      await _recordEntry.execute(
        RecordReservedKeychainDerivationCommand(
          reservationId: request.reservationId,
          parentFingerprint: request.parentFingerprint,
          walletMaterializations: request.materializations
              .map(_walletMaterializationCommand)
              .toList(growable: false),
        ),
        now: now,
      );
    } catch (e) {
      throw KeychainManifestException.fromInternal(e);
    }
  }

  RecordKeychainManifestWalletMaterializationCommand
  _walletMaterializationCommand(
    KeychainManifestWalletMaterializationRequest request,
  ) {
    return RecordKeychainManifestWalletMaterializationCommand(
      walletId: request.walletId,
      childSeedFingerprint: request.childSeedFingerprint,
      network: request.network.name,
      walletPurpose: request.walletPurpose,
      scriptType: request.scriptType.name,
    );
  }
}

class KeychainManifestReservedDerivationRequest {
  final String reservationId;
  final String parentFingerprint;
  final List<KeychainManifestWalletMaterializationRequest> materializations;

  const KeychainManifestReservedDerivationRequest({
    required this.reservationId,
    required this.parentFingerprint,
    required this.materializations,
  });
}

class KeychainManifestWalletMaterializationRequest {
  final String walletId;
  final String childSeedFingerprint;
  final Network network;
  final String walletPurpose;
  final ScriptType scriptType;

  const KeychainManifestWalletMaterializationRequest({
    required this.walletId,
    required this.childSeedFingerprint,
    required this.network,
    required this.walletPurpose,
    required this.scriptType,
  });
}

class KeychainManifestException implements Exception {
  final String message;
  final Object? cause;

  const KeychainManifestException(this.message, {this.cause});

  factory KeychainManifestException.fromInternal(Object error) {
    return switch (error) {
      KeychainManifestApplicationException(message: final message) =>
        KeychainManifestException(message, cause: error),
      KeychainManifestInvalidEntryException(message: final message) =>
        KeychainManifestException(message, cause: error),
      _ => KeychainManifestException(
        'keychain manifest operation failed',
        cause: error,
      ),
    };
  }

  @override
  String toString() => 'KeychainManifestException: $message';
}
