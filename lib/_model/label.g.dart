// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'label.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Label _$$_LabelFromJson(Map<String, dynamic> json) => _$_Label(
      type: $enumDecode(_$LabelTypeEnumMap, json['type']),
      ref: json['ref'] as String,
      label: json['label'] as String,
      origin: json['origin'] as String,
      spendable: json['spendable'] as bool,
    );

Map<String, dynamic> _$$_LabelToJson(_$_Label instance) => <String, dynamic>{
      'type': _$LabelTypeEnumMap[instance.type]!,
      'ref': instance.ref,
      'label': instance.label,
      'origin': instance.origin,
      'spendable': instance.spendable,
    };

const _$LabelTypeEnumMap = {
  LabelType.tx: 'tx',
  LabelType.address: 'address',
  LabelType.pubkey: 'pubkey',
  LabelType.input: 'input',
  LabelType.output: 'output',
  LabelType.xpub: 'xpub',
};
