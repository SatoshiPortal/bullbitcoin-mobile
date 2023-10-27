// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bip329_label.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Bip329Label _$$_Bip329LabelFromJson(Map<String, dynamic> json) =>
    _$_Bip329Label(
      type: $enumDecode(_$BIP329TypeEnumMap, json['type']),
      ref: json['ref'] as String,
      label: json['label'] as String?,
      origin: json['origin'] as String?,
      spendable: json['spendable'] as bool?,
    );

Map<String, dynamic> _$$_Bip329LabelToJson(_$_Bip329Label instance) =>
    <String, dynamic>{
      'type': _$BIP329TypeEnumMap[instance.type]!,
      'ref': instance.ref,
      'label': instance.label,
      'origin': instance.origin,
      'spendable': instance.spendable,
    };

const _$BIP329TypeEnumMap = {
  BIP329Type.tx: 'tx',
  BIP329Type.address: 'address',
  BIP329Type.pubkey: 'pubkey',
  BIP329Type.input: 'input',
  BIP329Type.output: 'output',
  BIP329Type.xpub: 'xpub',
};
