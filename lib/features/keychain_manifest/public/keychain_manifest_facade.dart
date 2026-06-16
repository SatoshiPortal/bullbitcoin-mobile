import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/application/application_errors.dart';
import 'package:bb_mobile/features/keychain_manifest/application/usecases/record_keychain_manifest_entry_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/domain_errors.dart';
import 'package:meta/meta.dart';

class KeychainManifestFacade {
  final RecordKeychainManifestEntryUsecase _recordEntry;

  KeychainManifestFacade({required this._recordEntry});

  Future<KeychainManifestRecordReservedDerivationResult>
  recordReservedDerivation(
    KeychainManifestReservedDerivationRequest request, {
    DateTime? now,
  }) async {
    try {
      final results = await _recordEntry.execute(
        RecordReservedKeychainDerivationCommand(
          reservationId: request.reservationId,
          parentFingerprint: request.parentFingerprint,
          walletMaterializations: request.materializations
              .map(_walletMaterializationCommand)
              .toList(growable: false),
        ),
        now: now,
      );
      return KeychainManifestRecordReservedDerivationResult._(
        insertedMaterializations: results
            .where((result) => result.inserted)
            .map((result) {
              return KeychainManifestRecordedMaterialization._wallet(
                entryId: result.record.entry.entryId,
                walletId: result.record.walletId,
              );
            })
            .toList(growable: false),
      );
    } catch (e) {
      throw KeychainManifestException.fromInternal(e);
    }
  }

  RecordKeychainManifestWalletMaterializationCommand
  _walletMaterializationCommand(
    KeychainManifestMaterializationRequest request,
  ) {
    if (request is! KeychainManifestWalletMaterializationRequest) {
      throw KeychainManifestUnsupportedMaterializationException(
        'unsupported keychain manifest materialization: ${request.runtimeType}',
      );
    }
    return RecordKeychainManifestWalletMaterializationCommand(
      walletId: request.walletId,
      childSeedFingerprint: request.childSeedFingerprint,
      network: request.network.name,
      walletPurpose: request.walletPurpose,
      scriptType: request.scriptType.name,
    );
  }
}

class KeychainManifestRecordReservedDerivationResult {
  final List<KeychainManifestRecordedMaterialization> insertedMaterializations;

  const KeychainManifestRecordReservedDerivationResult._({
    required this.insertedMaterializations,
  });

  @visibleForTesting
  const KeychainManifestRecordReservedDerivationResult.forTesting({
    required this.insertedMaterializations,
  });
}

class KeychainManifestRecordedMaterialization {
  static const walletType = 'wallet';

  final String entryId;
  final String materializationType;
  final String materializationId;

  const KeychainManifestRecordedMaterialization._({
    required this.entryId,
    required this.materializationType,
    required this.materializationId,
  });

  const KeychainManifestRecordedMaterialization._wallet({
    required String entryId,
    required String walletId,
  }) : this._(
         entryId: entryId,
         materializationType: walletType,
         materializationId: walletId,
       );

  @visibleForTesting
  const KeychainManifestRecordedMaterialization.walletForTesting({
    required String entryId,
    required String walletId,
  }) : this._wallet(entryId: entryId, walletId: walletId);
}

class KeychainManifestReservedDerivationRequest {
  final String reservationId;
  final String parentFingerprint;
  final List<KeychainManifestMaterializationRequest> materializations;

  const KeychainManifestReservedDerivationRequest({
    required this.reservationId,
    required this.parentFingerprint,
    required this.materializations,
  });
}

abstract class KeychainManifestMaterializationRequest {
  const KeychainManifestMaterializationRequest();
}

class KeychainManifestWalletMaterializationRequest
    extends KeychainManifestMaterializationRequest {
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
  }) : super();
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
      KeychainManifestUnsupportedMaterializationException(
        message: final message,
      ) =>
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

class KeychainManifestUnsupportedMaterializationException implements Exception {
  final String message;

  const KeychainManifestUnsupportedMaterializationException(this.message);
}
