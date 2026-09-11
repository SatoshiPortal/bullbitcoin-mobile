import 'dart:convert';

import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

final class NostrKey {
  final ECPrivate _privateKey;

  NostrKey._(this._privateKey);

  factory NostrKey.derive({required String rootXprv, required String path}) {
    final entropy = bip85.Bip85Entropy.deriveFromHardenedPath(
      xprvBase58: rootXprv,
      path: bip85.Bip85HardenedPath(path),
    );
    return NostrKey._(ECPrivate.fromHex(entropy.substring(0, 64)));
  }

  late final _publicKeyBytes = _privateKey.getPublic().toXOnly();

  late final String publicKeyHex = hex.encode(_publicKeyBytes);

  String signHash(String hashHex) =>
      _privateKey.signBip340(hex.decode(hashHex), tweak: false);

  /// An independent author for one prototype recovery locator. Secret stays here.
  NostrKey descriptorBackupScope(String lookup) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(lookup)) {
      throw const FormatException('Invalid descriptor lookup');
    }
    final order = BigInt.parse(
      'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
      radix: 16,
    );
    for (var counter = 0; counter < 256; counter++) {
      final digest = Hmac(sha256, _privateKey.toBytes()).convert([
        ...utf8.encode('bullvault-bip138-prototype-1/publisher'),
        0,
        ...hex.decode(lookup),
        counter,
      ]);
      final scalar = BigInt.parse(digest.toString(), radix: 16);
      if (scalar > BigInt.zero && scalar < order) {
        return NostrKey._(ECPrivate.fromHex(digest.toString()));
      }
    }
    throw StateError('Descriptor publishing key derivation failed');
  }

  @override
  String toString() => 'NostrKey(publicKeyHex: $publicKeyHex)';
}
