// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bip329_label.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$Bip329LabelImpl _$$Bip329LabelImplFromJson(Map<String, dynamic> json) =>
    _$Bip329LabelImpl(
      type: $enumDecode(_$BIP329TypeEnumMap, json['type']),
      ref: json['ref'] as String,
      label: json['label'] as String?,
      origin: json['origin'] as String?,
      spendable: json['spendable'] as bool?,
    );

Map<String, dynamic> _$$Bip329LabelImplToJson(_$Bip329LabelImpl instance) =>
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
