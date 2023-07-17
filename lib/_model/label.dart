// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'label.freezed.dart';
part 'label.g.dart';

enum LabelType { tx, address, pubkey, input, output, xpub }

@freezed
class Label with _$Label {
  const factory Label({
    required LabelType type,
    required String ref,
    required String label,
    required String origin,
    required bool spendable,
  }) = _Label;
  const Label._();

  factory Label.fromJson(Map<String, dynamic> json) => _$LabelFromJson(json);

  ///  TAG LIKE LABELLING SYSTEM
  ///  To stay within the BIP329 standard and support multiple labels per ref:
  ///  Use comma separated string where multiple labels exist
  List<String> labelList() => label.split(',');
}
