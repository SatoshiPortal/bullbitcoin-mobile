import 'dart:convert';
import 'dart:typed_data';
import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/utils/recoverbull_encryption.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/hkdf.dart';
import 'package:pointycastle/key_derivators/api.dart';

final class InvalidBackupPasswordException implements Exception {
  const InvalidBackupPasswordException();
}

/// Operation-scoped material. Neither phrase nor scalar is exposed or logged.
final class BackupPasswordMaterial {
  final Uint8List _encryptionKey;
  final ECPrivate _signer;
  BackupPasswordMaterial._(this._encryptionKey, this._signer);

  factory BackupPasswordMaterial.parse(String input) {
    if (input.length > 256) throw const InvalidBackupPasswordException();
    final words = input.trim().toLowerCase().split(RegExp(r'\s+'));
    if (words.length != 12) throw const InvalidBackupPasswordException();
    final List<int> entropy;
    try {
      entropy = bip39.Mnemonic.fromWords(words: words).entropy;
    } on Exception {
      // Mnemonic package errors contain the submitted words: discard entirely.
      throw const InvalidBackupPasswordException();
    }
    final root = _hkdf(entropy, 'encryption-v1', 32);
    final order = BigInt.parse(
      'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
      radix: 16,
    );
    for (var counter = 0; counter < 256; counter++) {
      final digest = Hmac(
        sha256,
        root,
      ).convert([...utf8.encode('nostr-auth-v1'), 0, counter]);
      final scalar = BigInt.parse(digest.toString(), radix: 16);
      if (scalar > BigInt.zero && scalar < order) {
        return BackupPasswordMaterial._(
          root,
          ECPrivate.fromHex(digest.toString()),
        );
      }
    }
    throw const InvalidBackupPasswordException();
  }

  static String deriveWords(String rootXprv) {
    final entropy = hex.decode(
      bip85.Bip85Entropy.deriveFromHardenedPath(
        xprvBase58: rootXprv,
        path: bip85.Bip85HardenedPath(
          Bip85Reservations.walletBackupEncryptionKey.path,
        ),
      ),
    );
    return bip39.Mnemonic(
      _hkdf(entropy, 'mnemonic-v1', 16),
      bip39.Language.english,
    ).sentence;
  }

  String get author => hex.encode(_signer.getPublic().toXOnly());
  String signHash(String hash) =>
      _signer.signBip340(hex.decode(hash), tweak: false);
  Future<Uint8List> encrypt(
    RecoverBullEncryption encryption,
    Uint8List plaintext,
  ) => encryption.encrypt(_encryptionKey, plaintext);
  Future<Uint8List> decrypt(
    RecoverBullEncryption encryption,
    Uint8List ciphertext,
  ) => encryption.decrypt(_encryptionKey, ciphertext);

  static Uint8List _hkdf(List<int> input, String info, int length) {
    final output = Uint8List(length);
    final derivator = HKDFKeyDerivator(SHA256Digest())
      ..init(
        HkdfParameters(
          Uint8List.fromList(input),
          length,
          Uint8List.fromList(utf8.encode('bullbitcoin-backup-password')),
          Uint8List.fromList(utf8.encode(info)),
        ),
      );
    derivator.deriveKey(null, 0, output, 0);
    return output;
  }
}
