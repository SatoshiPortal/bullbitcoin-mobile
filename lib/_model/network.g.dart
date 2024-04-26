// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BullbitcoinElectrumNetworkImpl _$$BullbitcoinElectrumNetworkImplFromJson(
        Map<String, dynamic> json) =>
    _$BullbitcoinElectrumNetworkImpl(
      mainnet: json['mainnet'] as String? ?? 'ssl://$bbelectrum:50002',
      testnet: json['testnet'] as String? ?? 'ssl://$bbelectrum:60002',
      stopGap: (json['stopGap'] as num?)?.toInt() ?? 20,
      timeout: (json['timeout'] as num?)?.toInt() ?? 5,
      retry: (json['retry'] as num?)?.toInt() ?? 5,
      validateDomain: json['validateDomain'] as bool? ?? true,
      name: json['name'] as String? ?? 'bullbitcoin',
      type: $enumDecodeNullable(_$ElectrumTypesEnumMap, json['type']) ??
          ElectrumTypes.bullbitcoin,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$BullbitcoinElectrumNetworkImplToJson(
        _$BullbitcoinElectrumNetworkImpl instance) =>
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

_$DefaultElectrumNetworkImpl _$$DefaultElectrumNetworkImplFromJson(
        Map<String, dynamic> json) =>
    _$DefaultElectrumNetworkImpl(
      mainnet: json['mainnet'] as String? ?? 'ssl://$openelectrum:50002',
      testnet: json['testnet'] as String? ?? 'ssl://$openelectrum:60002',
      stopGap: (json['stopGap'] as num?)?.toInt() ?? 20,
      timeout: (json['timeout'] as num?)?.toInt() ?? 5,
      retry: (json['retry'] as num?)?.toInt() ?? 5,
      validateDomain: json['validateDomain'] as bool? ?? true,
      name: json['name'] as String? ?? 'blockstream',
      type: $enumDecodeNullable(_$ElectrumTypesEnumMap, json['type']) ??
          ElectrumTypes.blockstream,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DefaultElectrumNetworkImplToJson(
        _$DefaultElectrumNetworkImpl instance) =>
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

_$CustomElectrumNetworkImpl _$$CustomElectrumNetworkImplFromJson(
        Map<String, dynamic> json) =>
    _$CustomElectrumNetworkImpl(
      mainnet: json['mainnet'] as String,
      testnet: json['testnet'] as String,
      stopGap: (json['stopGap'] as num?)?.toInt() ?? 20,
      timeout: (json['timeout'] as num?)?.toInt() ?? 5,
      retry: (json['retry'] as num?)?.toInt() ?? 5,
      validateDomain: json['validateDomain'] as bool? ?? true,
      name: json['name'] as String? ?? 'custom',
      type: $enumDecodeNullable(_$ElectrumTypesEnumMap, json['type']) ??
          ElectrumTypes.custom,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$CustomElectrumNetworkImplToJson(
        _$CustomElectrumNetworkImpl instance) =>
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

_$BlockstreamLiquidElectrumNetworkImpl
    _$$BlockstreamLiquidElectrumNetworkImplFromJson(
            Map<String, dynamic> json) =>
        _$BlockstreamLiquidElectrumNetworkImpl(
          mainnet: json['mainnet'] as String? ?? liquidElectrumUrl,
          testnet: json['testnet'] as String? ?? liquidElectrumTestUrl,
          validateDomain: json['validateDomain'] as bool? ?? true,
          name: json['name'] as String? ?? 'blockstream',
          type:
              $enumDecodeNullable(_$LiquidElectrumTypesEnumMap, json['type']) ??
                  LiquidElectrumTypes.blockstream,
          $type: json['runtimeType'] as String?,
        );

Map<String, dynamic> _$$BlockstreamLiquidElectrumNetworkImplToJson(
        _$BlockstreamLiquidElectrumNetworkImpl instance) =>
    <String, dynamic>{
      'mainnet': instance.mainnet,
      'testnet': instance.testnet,
      'validateDomain': instance.validateDomain,
      'name': instance.name,
      'type': _$LiquidElectrumTypesEnumMap[instance.type]!,
      'runtimeType': instance.$type,
    };

const _$LiquidElectrumTypesEnumMap = {
  LiquidElectrumTypes.blockstream: 'blockstream',
  LiquidElectrumTypes.custom: 'custom',
};

_$CustomLiquidElectrumNetworkImpl _$$CustomLiquidElectrumNetworkImplFromJson(
        Map<String, dynamic> json) =>
    _$CustomLiquidElectrumNetworkImpl(
      mainnet: json['mainnet'] as String,
      testnet: json['testnet'] as String,
      validateDomain: json['validateDomain'] as bool? ?? true,
      name: json['name'] as String? ?? 'custom',
      type: $enumDecodeNullable(_$LiquidElectrumTypesEnumMap, json['type']) ??
          LiquidElectrumTypes.custom,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$CustomLiquidElectrumNetworkImplToJson(
        _$CustomLiquidElectrumNetworkImpl instance) =>
    <String, dynamic>{
      'mainnet': instance.mainnet,
      'testnet': instance.testnet,
      'validateDomain': instance.validateDomain,
      'name': instance.name,
      'type': _$LiquidElectrumTypesEnumMap[instance.type]!,
      'runtimeType': instance.$type,
    };
