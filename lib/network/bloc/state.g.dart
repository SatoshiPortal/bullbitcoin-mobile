// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_NetworkState _$$_NetworkStateFromJson(Map<String, dynamic> json) =>
    _$_NetworkState(
      testnet: json['testnet'] as bool? ?? false,
      reloadWalletTimer: json['reloadWalletTimer'] as int? ?? 20,
      networks: (json['networks'] as List<dynamic>?)
              ?.map((e) => ElectrumNetwork.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      selectedNetwork: $enumDecodeNullable(
              _$ElectrumTypesEnumMap, json['selectedNetwork']) ??
          ElectrumTypes.bullbitcoin,
      loadingNetworks: json['loadingNetworks'] as bool? ?? false,
      errLoadingNetworks: json['errLoadingNetworks'] as String? ?? '',
      networkConnected: json['networkConnected'] as bool? ?? false,
      stopGap: json['stopGap'] as int? ?? 20,
      tempNetwork:
          $enumDecodeNullable(_$ElectrumTypesEnumMap, json['tempNetwork']),
    );

Map<String, dynamic> _$$_NetworkStateToJson(_$_NetworkState instance) =>
    <String, dynamic>{
      'testnet': instance.testnet,
      'reloadWalletTimer': instance.reloadWalletTimer,
      'networks': instance.networks,
      'selectedNetwork': _$ElectrumTypesEnumMap[instance.selectedNetwork]!,
      'loadingNetworks': instance.loadingNetworks,
      'errLoadingNetworks': instance.errLoadingNetworks,
      'networkConnected': instance.networkConnected,
      'stopGap': instance.stopGap,
      'tempNetwork': _$ElectrumTypesEnumMap[instance.tempNetwork],
    };

const _$ElectrumTypesEnumMap = {
  ElectrumTypes.blockstream: 'blockstream',
  ElectrumTypes.bullbitcoin: 'bullbitcoin',
  ElectrumTypes.custom: 'custom',
};
