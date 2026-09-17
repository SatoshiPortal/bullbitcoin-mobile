import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/derivers/bitcoin_deriver.dart';
import 'package:secrets/src/domain/domain.dart';

/// BIP85 children of a secret. Reached as `Deriver.bip85`.
///
/// The BIP85 root is an xprv, so these derivations happen inside the
/// package: handing the xprv out to let the app derive would be handing
/// out the seed in another encoding.
final class Bip85Deriver {
  const Bip85Deriver();

  /// The xprv BIP85 derives from — always the mainnet encoding.
  ///
  /// BIP85 entropy is an HMAC over a derived private key; the version
  /// bytes of the xprv it started from never enter it. There is no
  /// testnet BIP85: the same seed yields the same children on every
  /// chain, and the mainnet encoding is simply the canonical spelling.
  ///
  /// It is also the only spelling `bip85_entropy` accepts — it decodes
  /// with mainnet version bytes and refuses a `tprv` outright. The app
  /// used to hand it the wallet's network-encoded xprv, which made BIP85
  /// and the RecoverBull backup key fail on every non-mainnet wallet.
  /// That is why nothing BIP85-related takes a network.
  String root(SecretMaterial secret) =>
      const BitcoinDeriver().masterXprv(secret, BitcoinNetwork.mainnet);

  /// Child entropy, as hex.
  String hex(
    SecretMaterial secret, {
    required int numBytes,
    required int index,
  }) => hexFromRoot(root(secret), numBytes: numBytes, index: index);

  /// Child mnemonic words. Key material — a child the caller asked for.
  List<String> mnemonic(
    SecretMaterial secret, {
    required bip39.Language language,
    required bip39.MnemonicLength length,
    required int index,
  }) => mnemonicFromRoot(
    root(secret),
    language: language,
    length: length,
    index: index,
  );

  /// [hex], from a root already in hand.
  ///
  /// The seam the specification's vectors are pinned through: they start
  /// from a master key, not from words, so no [SecretMaterial] reproduces
  /// them. Package-internal; the xprv never leaves `crypto/`.
  String hexFromRoot(
    String xprv, {
    required int numBytes,
    required int index,
  }) => bip85.Bip85Entropy.deriveHex(
    xprvBase58: xprv,
    numBytes: numBytes,
    index: index,
  );

  /// [mnemonic], from a root already in hand. See [hexFromRoot].
  List<String> mnemonicFromRoot(
    String xprv, {
    required bip39.Language language,
    required bip39.MnemonicLength length,
    required int index,
  }) => bip85.Bip85Entropy.deriveMnemonic(
    xprvBase58: xprv,
    language: language,
    length: length,
    index: index,
  ).words;
}
