// ignore_for_file: invalid_annotation_target

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart' as pc;

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

  factory Bip329Label.fromJson(Map<String, dynamic> json) => _$Bip329LabelFromJson(json);

  ///  TAG LIKE LABELLING SYSTEM
  ///  To stay within the BIP329 standard and support multiple labels per ref:
  ///  Use comma separated string where multiple labels exist
  List<String> labelTagList() => label!.split(',');
}
//  4 method : readfile, writefile, encrypt, decrypt
// Existing Bip329Label class and other code...

extension Bip329LabelHelpers on Bip329Label {
  // Method to read labels from a file
  static Future<List<Bip329Label>> decryptRead(String fileName, String key) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    final encryptedContents = await file.readAsString();
    final decryptedContents = _decrypt(encryptedContents, key);
    final lines = LineSplitter.split(decryptedContents);
    return lines
        .map((line) => Bip329Label.fromJson(jsonDecode(line) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> encryptWrite(String fileName, List<Bip329Label> labels, String key) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    final dataToEncrypt = labels.map((label) => jsonEncode(label.toJson())).join('\n');
    final encryptedData = _encrypt(dataToEncrypt, key);
    await file.writeAsString(encryptedData);
  }
}

String _encrypt(String plainText, String key) {
  final keyBytes = Uint8List.fromList(utf8.encode(key));
  final keyParam = pc.KeyParameter(keyBytes);
  final blockCipher = pc.BlockCipher('AES')..init(true, keyParam);

  final input = Uint8List.fromList(utf8.encode(plainText));
  final encrypted = blockCipher.process(input);

  return base64Encode(encrypted);
}

String _decrypt(String encryptedBase64Text, String key) {
  final encryptedBytes = base64Decode(encryptedBase64Text);

  final keyBytes = Uint8List.fromList(utf8.encode(key));
  final keyParam = pc.KeyParameter(keyBytes);
  final blockCipher = pc.BlockCipher('AES')..init(false, keyParam);

  final decrypted = blockCipher.process(encryptedBytes);

  return utf8.decode(decrypted);
}
