import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/revealed_nostr_secret.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:primitives/primitives.dart';

final class RevealKeychainManifestNostrKeyUsecase {
  final KeychainManifestNostrKeyDeriver _deriver;

  const RevealKeychainManifestNostrKeyUsecase(this._deriver);

  Future<Result<RevealedNostrSecret, KeychainManifestFailure>> execute(
    KeychainManifestEntry entry,
  ) async {
    final key = entry.materializations.singleOrNull;
    if (key is! KeychainManifestNostrKey ||
        key.keyKind != KeychainManifestNostrKeyKind.userGenerated) {
      return const Err(KeychainManifestConflictFailure());
    }
    final source = await _deriver.source();
    if (source case Err(:final failure)) return Err(failure);
    final value =
        (source as Ok<KeychainManifestSeedSource, KeychainManifestFailure>)
            .value;
    if (value.fingerprint != entry.parentFingerprint) {
      return const Err(KeychainManifestSeedFailure());
    }
    final derived = _deriver.revealSecret(
      value.seed,
      entry.bip85DerivationPath,
    );
    if (derived.publicKeyHex != key.publicKeyHex) {
      return const Err(KeychainManifestDerivationFailure());
    }
    return Ok(RevealedNostrSecret(derived.nsec));
  }
}
