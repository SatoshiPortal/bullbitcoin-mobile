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

  Future<Result<bool, KeychainManifestFailure>> execute({
    required String reservationId,
    required Fingerprint parentFingerprint,
    required String derivationPath,
    required String publicKeyHex,
    required KeychainManifestNostrKeyKind keyKind,
    required String purpose,
    String? description,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    final source = await _deriver.source();
    switch (source) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.fingerprint != parentFingerprint ||
            _deriver.derivePublicKey(value.seed, derivationPath) !=
                publicKeyHex) {
          return const Err(KeychainManifestConflictFailure());
        }
    }
    return _record.execute(
      reservationId: reservationId,
      parentFingerprint: parentFingerprint,
      derivationPath: derivationPath,
      publicKeyHex: publicKeyHex,
      keyKind: keyKind,
      purpose: purpose,
      description: description,
      now: createdAt,
      updatedAt: updatedAt,
      origin: KeychainManifestWriteOrigin.recovery,
    );
  }
}
