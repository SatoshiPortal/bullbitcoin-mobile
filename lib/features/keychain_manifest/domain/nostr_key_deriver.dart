import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_path.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:nostr/nostr.dart' as nostr;

abstract final class NostrKeyDeriver {
  static nostr.Keys _derive(Seed seed, int identity) {
    final path = nostrUserKeyPath(identity);
    final root = Bip32Derivation.getXprvFromSeed(
      seed.bytes,
      Network.bitcoinMainnet,
    );
    final entropy = bip85.Bip85Entropy.deriveFromHardenedPath(
      xprvBase58: root,
      path: bip85.Bip85HardenedPath(path),
    );
    return nostr.Keys(entropy.substring(0, 64));
  }

  static String publicKey(Seed seed, int identity) =>
      _derive(seed, identity).public;

  static String npub(NostrKeyRecord record) =>
      encodePublicKey(record.publicKey);

  static String encodePublicKey(String publicKey) => nostr.Bech32Entity.encode(
    prefix: nostr.Nip19Prefix.npub,
    data: publicKey,
  );

  static String reveal(Seed seed, NostrKeyRecord record) {
    final keys = _derive(seed, record.identity);
    if (keys.public != record.publicKey ||
        seed.masterFingerprint.toLowerCase() != record.parentFingerprint) {
      throw const FormatException(
        'The local seed does not match this Nostr key',
      );
    }
    return keys.nsec;
  }
}
