// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SettingsStateImpl _$$SettingsStateImplFromJson(Map<String, dynamic> json) =>
    _$SettingsStateImpl(
      unitsInSats: json['unitsInSats'] as bool? ?? false,
      notifications: json['notifications'] as bool? ?? false,
      privacyView: json['privacyView'] as bool? ?? false,
      currency: json['currency'] == null
          ? null
          : Currency.fromJson(json['currency'] as Map<String, dynamic>),
      currencyList: (json['currencyList'] as List<dynamic>?)
          ?.map((e) => Currency.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastUpdatedCurrency: json['lastUpdatedCurrency'] == null
          ? null
          : DateTime.parse(json['lastUpdatedCurrency'] as String),
      loadingCurrency: json['loadingCurrency'] as bool? ?? false,
      errLoadingCurrency: json['errLoadingCurrency'] as String? ?? '',
      language: json['language'] as String?,
      languageList: (json['languageList'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      loadingLanguage: json['loadingLanguage'] as bool? ?? false,
      errLoadingLanguage: json['errLoadingLanguage'] as String? ?? '',
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
      fees: json['fees'] as int?,
      feesList:
          (json['feesList'] as List<dynamic>?)?.map((e) => e as int).toList(),
      selectedFeesOption: json['selectedFeesOption'] as int? ?? 2,
      tempFees: json['tempFees'] as int?,
      tempSelectedFeesOption: json['tempSelectedFeesOption'] as int?,
      feesSaved: json['feesSaved'] as bool? ?? false,
      loadingFees: json['loadingFees'] as bool? ?? false,
      errLoadingFees: json['errLoadingFees'] as String? ?? '',
      tempNetwork:
          $enumDecodeNullable(_$ElectrumTypesEnumMap, json['tempNetwork']),
      defaultRBF: json['defaultRBF'] as bool? ?? true,
    );

Map<String, dynamic> _$$SettingsStateImplToJson(_$SettingsStateImpl instance) =>
    <String, dynamic>{
      'unitsInSats': instance.unitsInSats,
      'notifications': instance.notifications,
      'privacyView': instance.privacyView,
      'currency': instance.currency,
      'currencyList': instance.currencyList,
      'lastUpdatedCurrency': instance.lastUpdatedCurrency?.toIso8601String(),
      'loadingCurrency': instance.loadingCurrency,
      'errLoadingCurrency': instance.errLoadingCurrency,
      'language': instance.language,
      'languageList': instance.languageList,
      'loadingLanguage': instance.loadingLanguage,
      'errLoadingLanguage': instance.errLoadingLanguage,
      'testnet': instance.testnet,
      'reloadWalletTimer': instance.reloadWalletTimer,
      'networks': instance.networks,
      'selectedNetwork': _$ElectrumTypesEnumMap[instance.selectedNetwork]!,
      'loadingNetworks': instance.loadingNetworks,
      'errLoadingNetworks': instance.errLoadingNetworks,
      'networkConnected': instance.networkConnected,
      'stopGap': instance.stopGap,
      'fees': instance.fees,
      'feesList': instance.feesList,
      'selectedFeesOption': instance.selectedFeesOption,
      'tempFees': instance.tempFees,
      'tempSelectedFeesOption': instance.tempSelectedFeesOption,
      'feesSaved': instance.feesSaved,
      'loadingFees': instance.loadingFees,
      'errLoadingFees': instance.errLoadingFees,
      'tempNetwork': _$ElectrumTypesEnumMap[instance.tempNetwork],
      'defaultRBF': instance.defaultRBF,
    };

const _$ElectrumTypesEnumMap = {
  ElectrumTypes.blockstream: 'blockstream',
  ElectrumTypes.bullbitcoin: 'bullbitcoin',
  ElectrumTypes.custom: 'custom',
};
