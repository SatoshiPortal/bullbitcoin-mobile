// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NetworkStateImpl _$$NetworkStateImplFromJson(Map<String, dynamic> json) =>
    _$NetworkStateImpl(
      testnet: json['testnet'] as bool? ?? false,
      reloadWalletTimer: (json['reloadWalletTimer'] as num?)?.toInt() ?? 20,
      networks: (json['networks'] as List<dynamic>?)
              ?.map((e) => ElectrumNetwork.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      selectedNetwork: $enumDecodeNullable(
              _$ElectrumTypesEnumMap, json['selectedNetwork']) ??
          ElectrumTypes.bullbitcoin,
      liquidNetworks: (json['liquidNetworks'] as List<dynamic>?)
              ?.map((e) =>
                  LiquidElectrumNetwork.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      selectedLiquidNetwork: $enumDecodeNullable(
              _$LiquidElectrumTypesEnumMap, json['selectedLiquidNetwork']) ??
          LiquidElectrumTypes.blockstream,
      loadingNetworks: json['loadingNetworks'] as bool? ?? false,
      errLoadingNetworks: json['errLoadingNetworks'] as String? ?? '',
      networkConnected: json['networkConnected'] as bool? ?? false,
      networkErrorOpened: json['networkErrorOpened'] as bool? ?? false,
      tempNetwork:
          $enumDecodeNullable(_$ElectrumTypesEnumMap, json['tempNetwork']),
      tempNetworkDetails: json['tempNetworkDetails'] == null
          ? null
          : ElectrumNetwork.fromJson(
              json['tempNetworkDetails'] as Map<String, dynamic>),
      tempLiquidNetwork: $enumDecodeNullable(
          _$LiquidElectrumTypesEnumMap, json['tempLiquidNetwork']),
      tempLiquidNetworkDetails: json['tempLiquidNetworkDetails'] == null
          ? null
          : LiquidElectrumNetwork.fromJson(
              json['tempLiquidNetworkDetails'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$NetworkStateImplToJson(_$NetworkStateImpl instance) =>
    <String, dynamic>{
      'testnet': instance.testnet,
      'reloadWalletTimer': instance.reloadWalletTimer,
      'networks': instance.networks,
      'selectedNetwork': _$ElectrumTypesEnumMap[instance.selectedNetwork]!,
      'liquidNetworks': instance.liquidNetworks,
      'selectedLiquidNetwork':
          _$LiquidElectrumTypesEnumMap[instance.selectedLiquidNetwork]!,
      'loadingNetworks': instance.loadingNetworks,
      'errLoadingNetworks': instance.errLoadingNetworks,
      'networkConnected': instance.networkConnected,
      'networkErrorOpened': instance.networkErrorOpened,
      'tempNetwork': _$ElectrumTypesEnumMap[instance.tempNetwork],
      'tempNetworkDetails': instance.tempNetworkDetails,
      'tempLiquidNetwork':
          _$LiquidElectrumTypesEnumMap[instance.tempLiquidNetwork],
      'tempLiquidNetworkDetails': instance.tempLiquidNetworkDetails,
    };

const _$ElectrumTypesEnumMap = {
  ElectrumTypes.blockstream: 'blockstream',
  ElectrumTypes.bullbitcoin: 'bullbitcoin',
  ElectrumTypes.custom: 'custom',
};

const _$LiquidElectrumTypesEnumMap = {
  LiquidElectrumTypes.blockstream: 'blockstream',
  LiquidElectrumTypes.custom: 'custom',
};
