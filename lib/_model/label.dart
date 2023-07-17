// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'label.freezed.dart';
part 'label.g.dart';

enum LabelType { tx, address, pubkey, input, output, xpub }

extension LabelTypeExtension on LabelType {
  String get value {
    switch (this) {
      case LabelType.tx:
        return 'tx';
      case LabelType.address:
        return 'address';
      case LabelType.pubkey:
        return 'pubkey';
      case LabelType.input:
        return 'input';
      case LabelType.output:
        return 'output';
      case LabelType.xpub:
        return 'xpub';
    }
  }

  set fromString(String value) => LabelType.values.byName(value);
}

@freezed
class Label with _$Label {
  const factory Label({
    required LabelType type,
    required String ref,
    String? label,
    String? origin,
    bool? spendable,
  }) = _Label;
  const Label._();

  factory Label.fromJson(Map<String, dynamic> json) => _$LabelFromJson(json);

  ///  TAG LIKE LABELLING SYSTEM
  ///  To stay within the BIP329 standard and support multiple labels per ref:
  ///  Use comma separated string where multiple labels exist
  List<String> labelList() => label!.split(',');
}
