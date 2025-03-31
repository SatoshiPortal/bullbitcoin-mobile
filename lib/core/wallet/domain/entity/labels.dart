// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'labels.freezed.dart';
part 'labels.g.dart';

enum LabelType { tx, address, pubkey, input, output, xpub }

// BIP329 Standard Label
@freezed
class Label with _$Label {
  const factory Label({
    required LabelType type,
    required String ref,
    required String label,
    String? origin,
    bool? spendable,
  }) = _Label;
  const Label._();

  factory Label.fromJson(Map<String, dynamic> json) => _$LabelFromJson(json);

  // ignore: prefer_constructors_over_static_methods
  static Label create({
    required LabelType type,
    required String ref,
    required String label,
    String? origin,
    bool? spendable,
  }) {
    final sanitizedLabel = label.replaceAll(',', '');

    return Label(
      type: type,
      ref: ref,
      label: sanitizedLabel,
      origin: origin,
      spendable: spendable,
    );
  }
}

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
