import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:nostr/nostr.dart' as nostr;

/// Operation-scoped keys for metadata encryption, artifacts and server requests.
/// This object is never retained in a bloc or singleton.
final class BackupCredential {
  final Uint8List _encryptionKey;
  final nostr.Keys _artifact;
  final nostr.Keys _server;

  BackupCredential._(this._encryptionKey, this._artifact, this._server);

  factory BackupCredential.fromSeed(Seed seed) =>
      BackupCredential.fromWords(deriveWords(seed));

  factory BackupCredential.fromWords(String input) {
    if (input.length > 256) {
      throw const FormatException('Invalid Data Recovery Words');
    }
    final words = input.trim().toLowerCase().split(RegExp(r'\s+'));
    if (words.length != 12 ||
        words.any((word) => !RegExp(r'^[a-z]+$').hasMatch(word))) {
      throw const FormatException('Invalid Data Recovery Words');
    }
    final bip39.Mnemonic mnemonic;
    try {
      mnemonic = bip39.Mnemonic.fromSentence(
        words.join(' '),
        bip39.Language.english,
      );
    } on Exception {
      throw const FormatException('Invalid Data Recovery Words');
    }
    final root = Bip32Derivation.getXprvFromSeed(
      Uint8List.fromList(mnemonic.seed),
      Network.bitcoinMainnet,
    );
    String child(String path) => bip85.Bip85Entropy.deriveFromHardenedPath(
      xprvBase58: root,
      path: bip85.Bip85HardenedPath(path),
    ).substring(0, 64);
    return BackupCredential._(
      Uint8List.fromList(
        hex.decode(child(Bip85Reservations.backupEncryptionKeyPath)),
      ),
      nostr.Keys(child(Bip85Reservations.backupArtifactIdentityPath)),
      nostr.Keys(child(Bip85Reservations.backupServerIdentityPath)),
    );
  }

  static String deriveWords(Seed seed) => bip85.Bip85Entropy.deriveMnemonic(
    xprvBase58: Bip32Derivation.getXprvFromSeed(
      seed.bytes,
      Network.bitcoinMainnet,
    ),
    language: bip39.Language.english,
    length: bip39.MnemonicLength.words12,
    index: Bip85Reservations.backupWords.index,
  ).sentence;

  Uint8List get encryptionKey => Uint8List.fromList(_encryptionKey);
  String get artifactPublicKey => _artifact.public;
  String get artifactNpub => _artifact.npub;
  String get serverPublicKey => _server.public;

  String signArtifactHash(String digest) => _sign(_artifact, digest);
  String signServerHash(String digest) => _sign(_server, digest);

  static String _sign(nostr.Keys identity, String digest) {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(digest)) {
      throw const FormatException('Expected a 32-byte digest');
    }
    return nostr.Schnorr.sign(
      secretKey: identity.secret,
      message: digest.toLowerCase(),
      aux: sha256.convert([
        ...hex.decode(digest),
        ...hex.decode(identity.secret),
      ]).toString(),
    );
  }

  @override
  String toString() => 'BackupCredential(<redacted>)';
}
