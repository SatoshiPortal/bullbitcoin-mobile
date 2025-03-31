// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'labels.freezed.dart';
part 'labels.g.dart';

enum BIP329Type { tx, address, pubkey, input, output, xpub }

@freezed
class Bip329Label with _$Bip329Label {
  const factory Bip329Label({
    required BIP329Type type,
    required String ref,
    required String label,
    String? origin,
    bool? spendable,
  }) = _Bip329Label;
  const Bip329Label._();

  factory Bip329Label.fromJson(Map<String, dynamic> json) =>
      _$Bip329LabelFromJson(json);

  static Bip329Label create({
    required BIP329Type type,
    required String ref,
    required String label,
    String? origin,
    bool? spendable,
  }) {
    final sanitizedLabel = label.replaceAll(',', '');

    return Bip329Label(
      type: type,
      ref: ref,
      label: sanitizedLabel,
      origin: origin,
      spendable: spendable,
    );
  }
}

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
