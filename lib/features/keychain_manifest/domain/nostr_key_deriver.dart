import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/nostr_bech32.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
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

  String derivePublicKey(Seed seed, String path) =>
      hex.encode(_derivePrivateKey(seed, path).getPublic().toXOnly());

  DerivedKeychainManifestNostrSecret revealSecret(Seed seed, String path) {
    final key = _derivePrivateKey(seed, path);
    return DerivedKeychainManifestNostrSecret(
      publicKeyHex: hex.encode(key.getPublic().toXOnly()),
      nsec: NostrBech32.nsec(hex.decode(key.toHex())),
    );
  }

  ECPrivate _derivePrivateKey(Seed seed, String path) {
    final entropy = bip85.Bip85Entropy.deriveFromHardenedPath(
      xprvBase58: Bip32Derivation.getCanonicalRootXprvFromSeed(seed.bytes),
      path: bip85.Bip85HardenedPath(path),
    );
    return ECPrivate.fromHex(entropy.substring(0, 64));
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
