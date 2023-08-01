// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address2.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Address2 _$$_Address2FromJson(Map<String, dynamic> json) => _$_Address2(
      address: json['address'] as String,
      index: json['index'] as int,
      type: $enumDecode(_$AddressTypeEnumMap, json['type']),
      txVIns:
          (json['txVIns'] as List<dynamic>?)?.map((e) => e as String).toList(),
      txVOuts:
          (json['txVOuts'] as List<dynamic>?)?.map((e) => e as String).toList(),
      balance: json['balance'] as int? ?? 0,
      label: json['label'] as String? ?? '',
    );

Map<String, dynamic> _$$_Address2ToJson(_$_Address2 instance) =>
    <String, dynamic>{
      'address': instance.address,
      'index': instance.index,
      'type': _$AddressTypeEnumMap[instance.type]!,
      'txVIns': instance.txVIns,
      'txVOuts': instance.txVOuts,
      'balance': instance.balance,
      'label': instance.label,
    };

const _$AddressTypeEnumMap = {
  AddressType.receiveActive: 'receiveActive',
  AddressType.receiveUnused: 'receiveUnused',
  AddressType.receiveUsed: 'receiveUsed',
  AddressType.changeActive: 'changeActive',
  AddressType.changeUsed: 'changeUsed',
  AddressType.notMine: 'notMine',
};
