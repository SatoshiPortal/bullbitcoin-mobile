// ignore_for_file: invalid_annotation_target

import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/_pkg/crypto.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path_provider/path_provider.dart';

part 'bip329_label.freezed.dart';
part 'bip329_label.g.dart';

enum BIP329Type { tx, address, pubkey, input, output, xpub }

extension LabelTypeExtension on BIP329Type {
  String get value {
    switch (this) {
      case BIP329Type.tx:
        return 'tx';
      case BIP329Type.address:
        return 'address';
      case BIP329Type.pubkey:
        return 'pubkey';
      case BIP329Type.input:
        return 'input';
      case BIP329Type.output:
        return 'output';
      case BIP329Type.xpub:
        return 'xpub';
    }
  }

  set fromString(String value) => BIP329Type.values.byName(value);
}

@freezed
class Bip329Label with _$Bip329Label {
  const factory Bip329Label({
    required BIP329Type type,
    required String ref,
    String? label,
    String? origin,
    bool? spendable,
  }) = _Bip329Label;
  const Bip329Label._();

  factory Bip329Label.fromJson(Map<String, dynamic> json) =>
      _$Bip329LabelFromJson(json);

  ///  TAG LIKE LABELLING SYSTEM
  ///  To stay within the BIP329 standard and support multiple labels per ref:
  ///  Use comma separated string where multiple labels exist
  List<String> labelTagList() => label!.split(',');
}

extension Bip329LabelHelpers on Bip329Label {
  static Future<(List<Bip329Label>?, Err?)> decryptRead(
    String fileName,
    String key,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName.export.bip329');
    if (await file.exists()) {
    } else {
      return (
        null,
        Err('No Label Export File Found!'),
      );
    }
    final encryptedContents = await file.readAsString();
    final decryptedContents = Crypto.aesDecrypt(encryptedContents, key);
    final lines = LineSplitter.split(decryptedContents);
    return (
      lines
          .map(
            (line) =>
                Bip329Label.fromJson(jsonDecode(line) as Map<String, dynamic>),
          )
          .toList(),
      null
    );
  }

  static Future<Err?> encryptWrite(
    String fileName,
    List<Bip329Label> labels,
    String key,
  ) async {
    if (labels.isEmpty) return Err('No Labels To Write.');
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName.export.bip329');
    final dataToEncrypt =
        labels.map((label) => jsonEncode(label.toJson())).join('\n');
    final encryptedData = _encrypt(dataToEncrypt, key);
    await file.writeAsString(encryptedData);
    return null;
  }
}

String _encrypt(String plainText, String key) {
  final keyBytes = Uint8List.fromList(_hexToIntList(key));
  final iv = generateRandomIV(16);
  final params = PaddedBlockCipherParameters(
    ParametersWithIV(KeyParameter(keyBytes), iv),
    null,
  );
  final paddedBlockCipher = pc.PaddedBlockCipher('AES/CBC/PKCS7')
    ..init(
      true,
      params,
    );

  final input = Uint8List.fromList(utf8.encode(plainText));
  final encrypted = paddedBlockCipher.process(input);

  return '${base64Encode(iv)},${base64Encode(encrypted)}';
}

String _decrypt(String encryptedBase64Text, String key) {
  final keyBytes = Uint8List.fromList(_hexToIntList(key));

  final parts = encryptedBase64Text.split(',');
  final iv = base64Decode(parts[0]);
  final encrypted = base64Decode(parts[1]);
  final params = PaddedBlockCipherParameters(
    ParametersWithIV(KeyParameter(keyBytes), iv),
    null,
  );
  final paddedBlockCipher = pc.PaddedBlockCipher('AES/CBC/PKCS7')
    ..init(
      false,
      params,
    );

  final decrypted = paddedBlockCipher.process(encrypted);

  return utf8.decode(decrypted);
}

List<int> _hexToIntList(String hex) {
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    final byteString = hex.substring(i, i + 2);
    final byte = int.parse(byteString, radix: 16);
    bytes.add(byte);
  }
  return bytes;
}

Uint8List generateRandomIV(int length) {
  final Random secureRandom = Random.secure();
  final Uint8List randomIV = Uint8List(length);
  for (int i = 0; i < length; i++) {
    randomIV[i] = secureRandom.nextInt(256);
  }
  return randomIV;
}
