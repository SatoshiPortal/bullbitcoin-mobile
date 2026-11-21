import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bs58/bs58.dart';
import 'package:convert/convert.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, ScriptType, ScriptTypeX, XpubType;
import 'package:satoshifier/satoshifier.dart';

class ExtendedPubkey {
  final List<int> pubkey;
  final XpubType type;
  final Derivation derivation;
  final Network network;

  ExtendedPubkey({
    required this.pubkey,
    type,
    required this.derivation,
    required this.network,
  }) : type = _typeForDerivation(derivation, network);

  static XpubType _typeForDerivation(Derivation derivation, Network network) {
    final bitcoinNetwork = switch (network) {
      Network.bitcoinMainnet => BitcoinNetwork.mainnet,
      Network.bitcoinTestnet => BitcoinNetwork.testnet,
      _ => throw 'Invalid derivation: $derivation for network: $network',
    };
    final scriptType = switch (derivation) {
      Derivation.bip44 => ScriptType.bip44,
      Derivation.bip49 => ScriptType.bip49,
      Derivation.bip84 => ScriptType.bip84,
    };
    return scriptType.getXpubType(bitcoinNetwork);
  }

  // Returns the base58 encoded xpub / ypub / zpub depending on the type
  String get pubBase58 => base58.encode(Uint8List.fromList(pubkey));
  String get xpub => Bip32Utils.convertToXpub(pubkey);

  String get fingerprint => hex.encode(Bip32Utils.fingerprint(pubkey, type));

  static ExtendedPubkey parse(String string) {
    final type = XpubType.tryFromPrefix(string);
    if (type == null) throw 'Invalid xpub type';
    // base58.decode does not verify the base58check trailer, so a mistyped or
    // truncated key parsed cleanly here and only surfaced downstream as
    // silently wrong addresses — a watch-only wallet built on the wrong key.
    // Bip32Keys does verify it. bypassVersion is required because ypub/zpub
    // carry SLIP-132 version bytes that it would otherwise reject outright;
    // the prefix itself is already checked above.
    try {
      Bip32Keys.fromBase58(string, bypassVersion: true);
    } on ArgumentError {
      throw FormatException('Invalid extended public key (base58check)');
    }
    final pubkey = base58.decode(string);
    final derivation = Derivation.fromXpubType(type);
    final network = Network.fromXpubType(type);
    return ExtendedPubkey(
      type: type,
      derivation: derivation,
      pubkey: pubkey,
      network: network,
    );
  }

  static ExtendedPubkey? tryParse(String string) {
    try {
      return parse(string);
    } catch (e) {
      return null;
    }
  }
}
