import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';

/// BIP85 application number for direct Nostr key derivation.
///
/// Path suffix: `9000'/{identity}'/{account_index}'`.
const int nostrBip85Application = 9000;

/// In-memory handle for a Nostr signing key.
///
/// Do not store this type in DTOs or persistence models. It exposes public-key
/// access and hash signing, but it does not expose raw secret-key material.
final class NostrKeychainHandle {
  final ECPrivate _key;

  NostrKeychainHandle._(this._key);

  factory NostrKeychainHandle._fromSecretKeyHex(String secretKeyHex) {
    return NostrKeychainHandle._(ECPrivate.fromHex(secretKeyHex));
  }

  factory NostrKeychainHandle.deriveFromBip85Path({
    required String xprvBase58,
    required String hardenedPath,
  }) {
    final path = bip85.Bip85HardenedPath(hardenedPath);
    final entropyHex = bip85.Bip85Entropy.deriveFromHardenedPath(
      xprvBase58: xprvBase58,
      path: path,
    );
    return NostrKeychainHandle._fromSecretKeyHex(entropyHex.substring(0, 64));
  }

  String get publicKeyHex => _key.getPublic().toXOnlyHex();

  String signHashHex(String messageHashHex) {
    final digest = hex.decode(messageHashHex);
    if (digest.length != 32) {
      throw ArgumentError.value(
        messageHashHex,
        'messageHashHex',
        'Nostr signing requires a 32-byte hash hex value',
      );
    }
    return _key.signBip340(digest, tweak: false);
  }

  @override
  String toString() => 'NostrKeychainHandle(publicKeyHex: $publicKeyHex)';
}
