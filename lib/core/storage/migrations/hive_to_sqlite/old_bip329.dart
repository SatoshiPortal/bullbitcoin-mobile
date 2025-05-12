import 'package:freezed_annotation/freezed_annotation.dart';

part 'old_bip329.freezed.dart';
part 'old_bip329.g.dart';

enum OldBIP329Type { tx, address, pubkey, input, output, xpub }

extension OldLabelTypeExtension on OldBIP329Type {
  String get value {
    switch (this) {
      case OldBIP329Type.tx:
        return 'tx';
      case OldBIP329Type.address:
        return 'address';
      case OldBIP329Type.pubkey:
        return 'pubkey';
      case OldBIP329Type.input:
        return 'input';
      case OldBIP329Type.output:
        return 'output';
      case OldBIP329Type.xpub:
        return 'xpub';
    }
  }

  set fromString(String value) => OldBIP329Type.values.byName(value);
}

@freezed
abstract class OldBip329Label with _$OldBip329Label {
  const factory OldBip329Label({
    required OldBIP329Type type,
    required String ref,
    String? label,
    String? origin,
    bool? spendable,
  }) = _Bip329Label;
  const OldBip329Label._();

  factory OldBip329Label.fromJson(Map<String, dynamic> json) =>
      _$Bip329LabelFromJson(json);

  ///  TAG LIKE LABELLING SYSTEM
  ///  To stay within the BIP329 standard and support multiple labels per ref:
  ///  Use comma separated string where multiple labels exist
  List<String> labelTagList() => label!.split(',');
}
