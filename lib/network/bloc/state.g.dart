// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_NetworkState _$$_NetworkStateFromJson(Map<String, dynamic> json) =>
    _$_NetworkState(
      testnet: json['testnet'] as bool? ?? false,
      loadingFees: json['loadingFees'] as bool? ?? false,
      errLoadingFees: json['errLoadingFees'] as String? ?? '',
    );

Map<String, dynamic> _$$_NetworkStateToJson(_$_NetworkState instance) =>
    <String, dynamic>{
      'testnet': instance.testnet,
      'loadingFees': instance.loadingFees,
      'errLoadingFees': instance.errLoadingFees,
    };
