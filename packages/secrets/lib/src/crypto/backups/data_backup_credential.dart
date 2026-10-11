import 'dart:typed_data';
import 'package:bip32_keys/bip32_keys.dart' as bip32;

import 'package:secrets/src/crypto/derivers/bip85_deriver.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:meta/meta.dart';
import 'package:recoverbull/recoverbull.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:nostr/nostr.dart' as nostr;

/// Operation-scoped keys for metadata encryption, artifacts and server requests.
/// This object is never retained in a bloc or singleton.
final class BackupCredential {
  static const backupWordsIndex = 100;
  static const backupEncryptionKeyPath = "128169'/32'/0'";
  static const backupArtifactIdentityPath = "128002'/100'/1'";
  static const backupServerIdentityPath = "128002'/101'/1'";

  final Uint8List _encryptionKey;
  final nostr.Keys _artifact;
  final nostr.Keys _server;
  final String? sourceFingerprint;

  BackupCredential._(
    this._encryptionKey,
    this._artifact,
    this._server,
    this.sourceFingerprint,
  );

  @internal
  factory BackupCredential.fromSeed(SecretMaterial seed) =>
      BackupCredential._fromWords(
        deriveWords(seed),
        sourceFingerprint: seed.id.hex,
      );

  factory BackupCredential.fromWords(String input) =>
      BackupCredential._fromWords(input);

  factory BackupCredential._fromWords(
    String input, {
    String? sourceFingerprint,
  }) {
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
    final root = bip32.Bip32Keys.fromSeed(
      Uint8List.fromList(mnemonic.seed),
    ).toBase58();
    String child(String path) => bip85.Bip85Entropy.deriveFromHardenedPath(
      xprvBase58: root,
      path: bip85.Bip85HardenedPath(path),
    ).substring(0, 64);
    return BackupCredential._(
      Uint8List.fromList(hex.decode(child(backupEncryptionKeyPath))),
      nostr.Keys(child(backupArtifactIdentityPath)),
      nostr.Keys(child(backupServerIdentityPath)),
      sourceFingerprint,
    );
  }

  @internal
  static String deriveWords(SecretMaterial seed) =>
      bip85.Bip85Entropy.deriveMnemonic(
        xprvBase58: const Bip85Deriver().root(seed),
        language: bip39.Language.english,
        length: bip39.MnemonicLength.words12,
        index: backupWordsIndex,
      ).sentence;

  Uint8List encrypt(List<int> plaintext) => Uint8List.fromList(
    RecoverBull.createBackup(
      backupKey: _encryptionKey,
      secret: plaintext,
    ).ciphertext,
  );

  Uint8List decrypt(List<int> ciphertext) => Uint8List.fromList(
    RecoverBull.restoreBackup(
      backupKey: _encryptionKey,
      backup: BullBackup(
        createdAt: 0,
        id: const [],
        salt: const [],
        ciphertext: ciphertext,
      ),
    ),
  );
  String get artifactPublicKey => _artifact.public;
  String get serverPublicKey => _server.public;

  // Only the sealed system-key view consumes these, after its reveal warning.
  @internal
  String revealArtifactNsec() => _artifact.nsec;
  @internal
  String revealServerNsec() => _server.nsec;

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
