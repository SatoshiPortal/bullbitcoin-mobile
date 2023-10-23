// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'electrum.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_BullbitcoinElectrumNetwork _$$_BullbitcoinElectrumNetworkFromJson(
        Map<String, dynamic> json) =>
    _$_BullbitcoinElectrumNetwork(
      mainnet: json['mainnet'] as String? ?? 'ssl://$bbelectrum:50002',
      testnet: json['testnet'] as String? ?? 'ssl://$bbelectrum:60002',
      stopGap: json['stopGap'] as int? ?? 20,
      timeout: json['timeout'] as int? ?? 5,
      retry: json['retry'] as int? ?? 5,
      validateDomain: json['validateDomain'] as bool? ?? true,
      name: json['name'] as String? ?? 'bullbitcoin',
      type: $enumDecodeNullable(_$ElectrumTypesEnumMap, json['type']) ??
          ElectrumTypes.bullbitcoin,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$_BullbitcoinElectrumNetworkToJson(
        _$_BullbitcoinElectrumNetwork instance) =>
    <String, dynamic>{
      'mainnet': instance.mainnet,
      'testnet': instance.testnet,
      'stopGap': instance.stopGap,
      'timeout': instance.timeout,
      'retry': instance.retry,
      'validateDomain': instance.validateDomain,
      'name': instance.name,
      'type': _$ElectrumTypesEnumMap[instance.type]!,
      'runtimeType': instance.$type,
    };

const _$ElectrumTypesEnumMap = {
  ElectrumTypes.blockstream: 'blockstream',
  ElectrumTypes.bullbitcoin: 'bullbitcoin',
  ElectrumTypes.custom: 'custom',
};

_$_DefaultElectrumNetwork _$$_DefaultElectrumNetworkFromJson(
        Map<String, dynamic> json) =>
    _$_DefaultElectrumNetwork(
      mainnet: json['mainnet'] as String? ?? 'ssl://$openelectrum:50002',
      testnet: json['testnet'] as String? ?? 'ssl://$openelectrum:60002',
      stopGap: json['stopGap'] as int? ?? 20,
      timeout: json['timeout'] as int? ?? 5,
      retry: json['retry'] as int? ?? 5,
      validateDomain: json['validateDomain'] as bool? ?? true,
      name: json['name'] as String? ?? 'blockstream',
      type: $enumDecodeNullable(_$ElectrumTypesEnumMap, json['type']) ??
          ElectrumTypes.blockstream,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$_DefaultElectrumNetworkToJson(
        _$_DefaultElectrumNetwork instance) =>
    <String, dynamic>{
      'mainnet': instance.mainnet,
      'testnet': instance.testnet,
      'stopGap': instance.stopGap,
      'timeout': instance.timeout,
      'retry': instance.retry,
      'validateDomain': instance.validateDomain,
      'name': instance.name,
      'type': _$ElectrumTypesEnumMap[instance.type]!,
      'runtimeType': instance.$type,
    };

_$_CustomElectrumNetwork _$$_CustomElectrumNetworkFromJson(
        Map<String, dynamic> json) =>
    _$_CustomElectrumNetwork(
      mainnet: json['mainnet'] as String,
      testnet: json['testnet'] as String,
      stopGap: json['stopGap'] as int? ?? 20,
      timeout: json['timeout'] as int? ?? 5,
      retry: json['retry'] as int? ?? 5,
      validateDomain: json['validateDomain'] as bool? ?? true,
      name: json['name'] as String? ?? 'custom',
      type: $enumDecodeNullable(_$ElectrumTypesEnumMap, json['type']) ??
          ElectrumTypes.custom,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$_CustomElectrumNetworkToJson(
        _$_CustomElectrumNetwork instance) =>
    <String, dynamic>{
      'mainnet': instance.mainnet,
      'testnet': instance.testnet,
      'stopGap': instance.stopGap,
      'timeout': instance.timeout,
      'retry': instance.retry,
      'validateDomain': instance.validateDomain,
      'name': instance.name,
      'type': _$ElectrumTypesEnumMap[instance.type]!,
      'runtimeType': instance.$type,
    };
