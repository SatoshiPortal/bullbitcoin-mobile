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
    final encryptedData = Crypto.aesEncrypt(dataToEncrypt, key);
    await file.writeAsString(encryptedData);
    return null;
  }
}
