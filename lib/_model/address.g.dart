// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Address _$$_AddressFromJson(Map<String, dynamic> json) => _$_Address(
      address: json['address'] as String,
      index: json['index'] as int?,
      kind: $enumDecode(_$AddressKindEnumMap, json['kind']),
      state: $enumDecode(_$AddressStatusEnumMap, json['state']),
      label: json['label'] as String?,
      spentTxId: json['spentTxId'] as String?,
      saving: json['saving'] as bool? ?? false,
      errSaving: json['errSaving'] as String? ?? '',
      highestPreviousBalance: json['highestPreviousBalance'] as int? ?? 0,
    );

Map<String, dynamic> _$$_AddressToJson(_$_Address instance) =>
    <String, dynamic>{
      'address': instance.address,
      'index': instance.index,
      'kind': _$AddressKindEnumMap[instance.kind]!,
      'state': _$AddressStatusEnumMap[instance.state]!,
      'label': instance.label,
      'spentTxId': instance.spentTxId,
      'saving': instance.saving,
      'errSaving': instance.errSaving,
      'highestPreviousBalance': instance.highestPreviousBalance,
    };

const _$AddressKindEnumMap = {
  AddressKind.deposit: 'deposit',
  AddressKind.change: 'change',
  AddressKind.external: 'external',
};

const _$AddressStatusEnumMap = {
  AddressStatus.unset: 'unset',
  AddressStatus.unused: 'unused',
  AddressStatus.active: 'active',
  AddressStatus.frozen: 'frozen',
  AddressStatus.used: 'used',
};
