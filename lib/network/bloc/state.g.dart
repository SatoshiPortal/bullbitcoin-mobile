// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NetworkStateImpl _$$NetworkStateImplFromJson(Map<String, dynamic> json) =>
    _$NetworkStateImpl(
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
      tempNetwork:
          $enumDecodeNullable(_$ElectrumTypesEnumMap, json['tempNetwork']),
      tempNetworkDetails: json['tempNetworkDetails'] == null
          ? null
          : ElectrumNetwork.fromJson(
              json['tempNetworkDetails'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$NetworkStateImplToJson(_$NetworkStateImpl instance) =>
    <String, dynamic>{
      'testnet': instance.testnet,
      'reloadWalletTimer': instance.reloadWalletTimer,
      'networks': instance.networks,
      'selectedNetwork': _$ElectrumTypesEnumMap[instance.selectedNetwork]!,
      'loadingNetworks': instance.loadingNetworks,
      'errLoadingNetworks': instance.errLoadingNetworks,
      'networkConnected': instance.networkConnected,
      'tempNetwork': _$ElectrumTypesEnumMap[instance.tempNetwork],
      'tempNetworkDetails': instance.tempNetworkDetails,
    };

const _$ElectrumTypesEnumMap = {
  ElectrumTypes.blockstream: 'blockstream',
  ElectrumTypes.bullbitcoin: 'bullbitcoin',
  ElectrumTypes.custom: 'custom',
};
