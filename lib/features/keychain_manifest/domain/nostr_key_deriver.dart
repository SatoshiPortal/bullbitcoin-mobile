import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:nostr/nostr.dart' as nostr;
import 'package:primitives/primitives.dart';

final class KeychainManifestNostrKeyDeriver {
  final GetSettingsUsecase _settings;
  final GetDefaultSeedUsecase _defaultSeed;

  const KeychainManifestNostrKeyDeriver(this._settings, this._defaultSeed);

  Future<Result<KeychainManifestSeedSource, KeychainManifestFailure>>
  source() async {
    try {
      final settings = await _settings.execute();
      return switch (await _defaultSeed.execute(
        environment: settings.environment,
      )) {
        Ok(:final value) => Ok(
          KeychainManifestSeedSource(
            value,
            Fingerprint.tryParse(value.masterFingerprint)!,
          ),
        ),
        Err() => const Err(KeychainManifestSeedFailure()),
      };
    } on Exception {
      return const Err(KeychainManifestSeedFailure());
    }
  }

  String derivePublicKey(
    Seed seed,
    String path, {
    KeychainManifestDerivationKind kind = KeychainManifestDerivationKind.bip85,
  }) => _deriveKeys(seed, path, kind).public;

  DerivedKeychainManifestNostrSecret revealSecret(
    Seed seed,
    String path, {
    KeychainManifestDerivationKind kind = KeychainManifestDerivationKind.bip85,
  }) {
    final keys = _deriveKeys(seed, path, kind);
    return DerivedKeychainManifestNostrSecret(
      publicKeyHex: keys.public,
      nsec: keys.nsec,
    );
  }

  /// Executes the manifest's derivation instruction literally.
  ///
  /// A `bip85` path is one BIP85 derivation on the parent seed. A `bip85Chain`
  /// is the same operation repeated: every step but the last is a BIP85
  /// application-39 path whose English mnemonic, with an empty passphrase, is
  /// the BIP32 root the next step derives from. The final step's first 32
  /// bytes of entropy are the secp256k1 secret, the rule every Nostr key in
  /// the app follows. The secret becomes a `nostr` package [nostr.Keys], which
  /// checks the scalar range and produces the public key, npub and nsec.
  nostr.Keys _deriveKeys(
    Seed seed,
    String path,
    KeychainManifestDerivationKind kind,
  ) {
    final steps = switch (kind) {
      KeychainManifestDerivationKind.bip85 => [path],
      KeychainManifestDerivationKind.bip85Chain =>
        KeychainManifestEntry.chainSteps(
          KeychainManifestEntry.canonicalPath(kind, path),
        ),
      KeychainManifestDerivationKind.bip32 => throw ArgumentError.value(
        kind,
        'kind',
        'Nostr keys are BIP85 derivations',
      ),
    };
    var root = Bip32Derivation.getCanonicalRootXprvFromSeed(seed.bytes);
    for (final step in steps.take(steps.length - 1)) {
      final words = bip85.Bip85Entropy.deriveFromHardenedPath(
        xprvBase58: root,
        path: bip85.Bip85HardenedPath(step),
      );
      root = Bip32Derivation.getCanonicalRootXprvFromSeed(
        Uint8List.fromList(
          bip39.Mnemonic.fromSentence(words, bip39.Language.english).seed,
        ),
      );
    }
    final entropy = bip85.Bip85Entropy.deriveFromHardenedPath(
      xprvBase58: root,
      path: bip85.Bip85HardenedPath(steps.last),
    );
    return nostr.Keys(entropy.substring(0, 64));
  }
}

final class KeychainManifestSeedSource {
  final Seed seed;
  final Fingerprint fingerprint;

  const KeychainManifestSeedSource(this.seed, this.fingerprint);
}

final class DerivedKeychainManifestNostrSecret {
  final String publicKeyHex;
  final String nsec;

  const DerivedKeychainManifestNostrSecret({
    required this.publicKeyHex,
    required this.nsec,
  });
}
