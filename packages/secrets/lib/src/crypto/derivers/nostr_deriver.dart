import 'package:meta/meta.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:nostr/nostr.dart' as nostr;
import 'package:secrets/src/crypto/derivers/bip85_deriver.dart';
import 'package:secrets/src/domain/domain.dart';

final class NostrDeriver {
  @internal
  const NostrDeriver();

  nostr.Keys derive(SecretMaterial secret, int identity) {
    if (identity < 1 ||
        identity > 0x7fffffff ||
        (identity >= 100 && identity <= 199)) {
      throw const FormatException('Invalid Nostr key index');
    }
    final entropy = bip85.Bip85Entropy.deriveFromHardenedPath(
      xprvBase58: const Bip85Deriver().root(secret),
      path: bip85.Bip85HardenedPath("128002'/$identity'/1'"),
    );
    return nostr.Keys(entropy.substring(0, 64));
  }
}
