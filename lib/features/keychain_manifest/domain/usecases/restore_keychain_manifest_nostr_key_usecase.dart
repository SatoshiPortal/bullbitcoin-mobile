import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_nostr_key_usecase.dart';
import 'package:primitives/primitives.dart';

final class RestoreKeychainManifestNostrKeyUsecase {
  final KeychainManifestNostrKeyDeriver _deriver;
  final RecordKeychainManifestNostrKeyUsecase _record;

  const RestoreKeychainManifestNostrKeyUsecase(this._deriver, this._record);

  /// Records a key only after re-deriving it from the active seed by the
  /// entry's own instruction, so a manifest can never carry a key its
  /// derivation does not produce. Recovery and local registration share this
  /// check; only the recorded [origin] differs.
  Future<Result<bool, KeychainManifestFailure>> execute({
    required String reservationId,
    required Fingerprint parentFingerprint,
    KeychainManifestDerivationKind derivationKind =
        KeychainManifestDerivationKind.bip85,
    required String derivationPath,
    required String publicKeyHex,
    required KeychainManifestNostrKeyKind keyKind,
    required String purpose,
    String? description,
    required DateTime createdAt,
    required DateTime updatedAt,
    KeychainManifestWriteOrigin origin = KeychainManifestWriteOrigin.recovery,
  }) async {
    if (derivationKind == KeychainManifestDerivationKind.bip32) {
      return const Err(KeychainManifestUnknownReservationFailure());
    }
    final source = await _deriver.source();
    switch (source) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final String derived;
        try {
          derived = _deriver.derivePublicKey(
            value.seed,
            derivationPath,
            kind: derivationKind,
          );
        } on ArgumentError {
          return const Err(KeychainManifestUnknownReservationFailure());
        }
        if (value.fingerprint != parentFingerprint ||
            derived != publicKeyHex.toLowerCase()) {
          return const Err(KeychainManifestConflictFailure());
        }
    }
    return _record.execute(
      reservationId: reservationId,
      parentFingerprint: parentFingerprint,
      derivationKind: derivationKind,
      derivationPath: derivationPath,
      publicKeyHex: publicKeyHex,
      keyKind: keyKind,
      purpose: purpose,
      description: description,
      now: createdAt,
      updatedAt: updatedAt,
      origin: origin,
    );
  }
}
