import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';

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

  @override
  String toString() => 'NostrKey(publicKeyHex: $publicKeyHex)';
}
