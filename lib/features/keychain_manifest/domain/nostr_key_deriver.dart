import 'package:nostr/nostr.dart' as nostr;

abstract final class NostrKeyDeriver {
  static String encodePublicKey(String publicKey) => nostr.Bech32Entity.encode(
    prefix: nostr.Nip19Prefix.npub,
    data: publicKey,
  );
}
