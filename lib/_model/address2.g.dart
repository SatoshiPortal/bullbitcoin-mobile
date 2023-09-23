// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address2.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Address2 _$$_Address2FromJson(Map<String, dynamic> json) => _$_Address2(
      address: json['address'] as String,
      index: json['index'] as int,
      kind: $enumDecode(_$AddressKindEnumMap, json['kind']),
      state: $enumDecode(_$AddressStateEnumMap, json['state']),
      label: json['label'] as String?,
      spentTxId: json['spentTxId'] as String?,
      isReceive: json['isReceive'] as bool?,
      saving: json['saving'] as bool? ?? false,
      errSaving: json['errSaving'] as String? ?? '',
      highestPreviousBalance: json['highestPreviousBalance'] as int? ?? 0,
    );

Map<String, dynamic> _$$_Address2ToJson(_$_Address2 instance) =>
    <String, dynamic>{
      'address': instance.address,
      'index': instance.index,
      'kind': _$AddressKindEnumMap[instance.kind]!,
      'state': _$AddressStateEnumMap[instance.state]!,
      'label': instance.label,
      'spentTxId': instance.spentTxId,
      'isReceive': instance.isReceive,
      'saving': instance.saving,
      'errSaving': instance.errSaving,
      'highestPreviousBalance': instance.highestPreviousBalance,
    };

const _$AddressKindEnumMap = {
  AddressKind.deposit: 'deposit',
  AddressKind.change: 'change',
  AddressKind.external: 'external',
};

const _$AddressStateEnumMap = {
  AddressState.unset: 'unset',
  AddressState.unused: 'unused',
  AddressState.active: 'active',
  AddressState.frozen: 'frozen',
  AddressState.used: 'used',
};
