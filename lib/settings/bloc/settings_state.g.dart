// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SettingsStateImpl _$$SettingsStateImplFromJson(Map<String, dynamic> json) =>
    _$SettingsStateImpl(
      notifications: json['notifications'] as bool? ?? false,
      privacyView: json['privacyView'] as bool? ?? false,
      reloadWalletTimer: (json['reloadWalletTimer'] as num?)?.toInt() ?? 20,
      language: json['language'] as String?,
      languageList: (json['languageList'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      loadingLanguage: json['loadingLanguage'] as bool? ?? false,
      errLoadingLanguage: json['errLoadingLanguage'] as String? ?? '',
      defaultRBF: json['defaultRBF'] as bool? ?? true,
      homeLayout: (json['homeLayout'] as num?)?.toInt() ?? 1,
      removeSwapWarnings: json['removeSwapWarnings'] as bool? ?? false,
    );

Map<String, dynamic> _$$SettingsStateImplToJson(_$SettingsStateImpl instance) =>
    <String, dynamic>{
      'notifications': instance.notifications,
      'privacyView': instance.privacyView,
      'reloadWalletTimer': instance.reloadWalletTimer,
      'language': instance.language,
      'languageList': instance.languageList,
      'loadingLanguage': instance.loadingLanguage,
      'errLoadingLanguage': instance.errLoadingLanguage,
      'defaultRBF': instance.defaultRBF,
      'homeLayout': instance.homeLayout,
      'removeSwapWarnings': instance.removeSwapWarnings,
    };
