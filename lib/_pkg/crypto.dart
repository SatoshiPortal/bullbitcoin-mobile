import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:hex/hex.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/export.dart' as pc;

class Crypto {
  static String aesEncrypt(String plainText, String key) {
    final keyBytes = Uint8List.fromList(HEX.decode(key));
    final iv = generateRandomBytes(16);
    final params = PaddedBlockCipherParameters(
      ParametersWithIV(KeyParameter(keyBytes), iv),
      null,
    );
    final paddedBlockCipher = pc.PaddedBlockCipher('AES/CBC/PKCS7')
      ..init(true, params);

    final input = Uint8List.fromList(utf8.encode(plainText));
    final encrypted = paddedBlockCipher.process(input);

    return '${base64Encode(iv)},${base64Encode(encrypted)}';
  }

  static String aesDecrypt(String encryptedBase64Text, String key) {
    final keyBytes = Uint8List.fromList(HEX.decode(key));

    final parts = encryptedBase64Text.split(',');
    final iv = base64Decode(parts[0]);
    final encrypted = base64Decode(parts[1]);
    final params = PaddedBlockCipherParameters(
      ParametersWithIV(KeyParameter(keyBytes), iv),
      null,
    );
    final paddedBlockCipher = pc.PaddedBlockCipher('AES/CBC/PKCS7')
      ..init(false, params);

    final decrypted = paddedBlockCipher.process(encrypted);

    return utf8.decode(decrypted);
  }

  static Uint8List generateRandomBytes(int length) {
    final secureRandom = Random.secure();
    final randomIV = Uint8List(length);
    for (int i = 0; i < length; i++) {
      randomIV[i] = secureRandom.nextInt(256);
    }
    return randomIV;
  }

  static List<int> sha256(List<int> input) {
    return SHA256Digest().process(Uint8List.fromList(input));
  }
}
