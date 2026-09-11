import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Binary profile pinned to BIP PR1951 at 5af62cba; see prototype documentation.
/// Descriptor grammar/key eligibility are checked by the repository before encode.
final class Bip138Codec {
  static const maxBytes = 32768;
  final Random _random;

  Bip138Codec() : _random = Random.secure();

  Uint8List encode(String descriptor, List<Uint8List> xOnlyKeys) {
    final content = utf8.encode(descriptor);
    if (content.isEmpty || content.length > maxBytes - 1024) {
      throw const FormatException('Descriptor size');
    }
    final keys = xOnlyKeys.map(hex.encode).toSet().toList()..sort();
    if (keys.isEmpty ||
        keys.length > 5 ||
        keys.any(
          (key) =>
              key.length != 64 ||
              key ==
                  '50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0',
        )) {
      throw const FormatException('Unsupported recipients');
    }
    final secret = taggedHash(
      'BIP138_DECRYPTION_SECRET',
      keys.expand(hex.decode).toList(),
    );
    final masks = keys
        .map(
          (key) => hex.encode(
            _xor(
              secret,
              taggedHash('BIP138_INDIVIDUAL_SECRET', hex.decode(key)),
            ),
          ),
        )
        .toSet();
    while (masks.length < 5) {
      masks.add(hex.encode(randomBytes(32)));
    }
    final sortedMasks = masks.toList()..sort();
    final nonce = randomNonce();
    final ciphertext = crypt(true, secret, nonce, [
      1,
      1,
      124,
      ...compact(content.length),
      ...content,
    ]);
    return Uint8List.fromList([
      ...ascii.encode('BIP138'),
      1,
      0,
      sortedMasks.length,
      ...sortedMasks.expand(hex.decode),
      1,
      ...nonce,
      ...compact(ciphertext.length),
      ...ciphertext,
    ]);
  }

  /// Returns BIP380 content items; other non-critical items are safely skipped.
  List<String> decode(Uint8List bytes, Uint8List xOnlyKey) {
    if (bytes.length > maxBytes || xOnlyKey.length != 32) {
      throw const FormatException('Backup size or key');
    }
    final input = _Reader(bytes);
    if (ascii.decode(input.take(6)) != 'BIP138' || input.byte() != 1) {
      throw const FormatException('Unsupported BIP138 profile');
    }
    final paths = input.byte();
    for (var i = 0; i < paths; i++) {
      final children = input.byte();
      if (children == 0) throw const FormatException('Empty path');
      input.take(children * 4);
    }
    final count = input.byte();
    if (count == 0) throw const FormatException('No recipients');
    final masks = List.generate(count, (_) => input.take(32));
    if (input.byte() != 1) {
      throw const FormatException('Unsupported encryption');
    }
    final nonce = input.take(12);
    if (nonce.every((b) => b == 0)) throw const FormatException('Zero nonce');
    final ciphertext = input.take(input.compact());
    if (ciphertext.length <= 16) throw const FormatException('Empty payload');
    // Bytes beyond the declared ciphertext are extensions per the BIP.
    final individual = taggedHash('BIP138_INDIVIDUAL_SECRET', xOnlyKey);
    for (final mask in masks) {
      final Uint8List plaintext;
      try {
        plaintext = crypt(false, _xor(mask, individual), nonce, ciphertext);
      } on InvalidCipherTextException {
        continue;
      }
      return _contents(plaintext);
    }
    throw const FormatException('Backup cannot be decrypted');
  }

  List<String> _contents(Uint8List bytes) {
    final input = _Reader(bytes);
    final descriptors = <String>[];
    var items = 0;
    while (input.remaining > 0) {
      final type = input.byte();
      if (type == 0) break;
      if (type >= 128) throw const FormatException('Critical content type');
      final params = input.take(type == 1 ? 2 : input.compact());
      final content = input.take(input.compact());
      if (type == 3) {
        if (params.isNotEmpty) throw const FormatException('String parameters');
        utf8.decode(content);
      }
      if (type == 1 && params[0] == 1 && params[1] == 124) {
        descriptors.add(utf8.decode(content));
      }
      items++;
    }
    if (items == 0) throw const FormatException('No content items');
    return descriptors;
  }

  Uint8List randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

  Uint8List randomNonce() {
    Uint8List nonce;
    do {
      nonce = randomBytes(12);
    } while (nonce.every((b) => b == 0));
    return nonce;
  }

  static Uint8List taggedHash(String tag, List<int> bytes) {
    final hash = sha256.convert(utf8.encode(tag)).bytes;
    return Uint8List.fromList(
      sha256.convert([...hash, ...hash, ...bytes]).bytes,
    );
  }

  static Uint8List crypt(
    bool encrypt,
    List<int> key,
    List<int> nonce,
    List<int> bytes, [
    List<int> aad = const [],
  ]) {
    final cipher = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305())
      ..init(
        encrypt,
        AEADParameters(
          KeyParameter(Uint8List.fromList(key)),
          128,
          Uint8List.fromList(nonce),
          Uint8List.fromList(aad),
        ),
      );
    final input = Uint8List.fromList(bytes);
    final output = Uint8List(cipher.getOutputSize(input.length));
    var written = cipher.processBytes(input, 0, input.length, output, 0);
    try {
      // PointyCastle 3.9.1's inherited process() omits doFinal entirely.
      // Finalization writes/checks the authentication tag and trailing bytes.
      written += cipher.doFinal(output, written);
    } on ArgumentError catch (error) {
      // This dependency uses ArgumentError specifically for an invalid MAC.
      if (!encrypt && error.message == 'mac check in ChaCha20Poly1305 failed') {
        throw InvalidCipherTextException('Authentication failed');
      }
      rethrow;
    }
    return Uint8List.sublistView(output, 0, written);
  }

  static List<int> compact(int value) {
    if (value < 0 || value > maxBytes) throw const FormatException('Length');
    if (value < 253) return [value];
    return [253, value & 255, value >> 8];
  }

  static Uint8List _xor(List<int> a, List<int> b) =>
      Uint8List.fromList(List.generate(32, (i) => a[i] ^ b[i]));
}

final class _Reader {
  final Uint8List bytes;
  int offset = 0;
  _Reader(this.bytes);
  int get remaining => bytes.length - offset;
  int byte() => take(1)[0];
  Uint8List take(int count) {
    if (count < 0 || count > remaining) {
      throw const FormatException('Truncated backup');
    }
    final result = Uint8List.sublistView(bytes, offset, offset + count);
    offset += count;
    return result;
  }

  int compact() {
    final first = byte();
    if (first < 253) return first;
    final length = first == 253
        ? 2
        : first == 254
        ? 4
        : 8;
    final raw = take(length);
    var value = 0;
    for (var i = length - 1; i >= 0; i--) {
      value = value * 256 + raw[i];
      if (value > Bip138Codec.maxBytes) {
        throw const FormatException('Length exceeds limit');
      }
    }
    if ((first == 253 && value < 253) ||
        (first == 254 && value <= 65535) ||
        first == 255) {
      throw const FormatException('Noncanonical length');
    }
    return value;
  }
}
