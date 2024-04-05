// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bitcoin_address.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BitcoinAddressImpl _$$BitcoinAddressImplFromJson(Map<String, dynamic> json) =>
    _$BitcoinAddressImpl(
      address: json['address'] as String,
      index: json['index'] as int,
      kind: $enumDecode(_$AddressKindEnumMap, json['kind']),
      status: $enumDecode(_$AddressStatusEnumMap, json['status']),
      type: $enumDecode(_$AddressTypeEnumMap, json['type']),
      balance: json['balance'] as int,
      spendable: json['spendable'] as bool,
      labels:
          (json['labels'] as List<dynamic>?)?.map((e) => e as String).toList(),
      txId: json['txId'] as String?,
      walletId: json['walletId'] as String?,
    )..state = $enumDecode(_$AddressStatusEnumMap, json['state']);

Map<String, dynamic> _$$BitcoinAddressImplToJson(
        _$BitcoinAddressImpl instance) =>
    <String, dynamic>{
      'state': _$AddressStatusEnumMap[instance.state]!,
      'address': instance.address,
      'index': instance.index,
      'kind': _$AddressKindEnumMap[instance.kind]!,
      'status': _$AddressStatusEnumMap[instance.status]!,
      'type': _$AddressTypeEnumMap[instance.type]!,
      'balance': instance.balance,
      'spendable': instance.spendable,
      'labels': instance.labels,
      'txId': instance.txId,
      'walletId': instance.walletId,
    };

const _$AddressKindEnumMap = {
  AddressKind.deposit: 'deposit',
  AddressKind.change: 'change',
  AddressKind.external: 'external',
};

const _$AddressStatusEnumMap = {
  AddressStatus.unused: 'unused',
  AddressStatus.active: 'active',
  AddressStatus.used: 'used',
  AddressStatus.copied: 'copied',
};

const _$AddressTypeEnumMap = {
  AddressType.Bitcoin: 'Bitcoin',
  AddressType.Liquid: 'Liquid',
  AddressType.Lightning: 'Lightning',
  AddressType.Usdt: 'Usdt',
};