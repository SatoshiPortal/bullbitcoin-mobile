// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cold_card.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_ColdCard _$$_ColdCardFromJson(Map<String, dynamic> json) => _$_ColdCard(
      chain: json['chain'] as String?,
      xpub: json['xpub'] as String?,
      xfp: json['xfp'] as String?,
      account: json['account'] as int?,
      bip49: json['bip49'] == null
          ? null
          : ColdWallet.fromJson(json['bip49'] as Map<String, dynamic>),
      bip44: json['bip44'] == null
          ? null
          : ColdWallet.fromJson(json['bip44'] as Map<String, dynamic>),
      bip84: json['bip84'] == null
          ? null
          : ColdWallet.fromJson(json['bip84'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$_ColdCardToJson(_$_ColdCard instance) =>
    <String, dynamic>{
      'chain': instance.chain,
      'xpub': instance.xpub,
      'xfp': instance.xfp,
      'account': instance.account,
      'bip49': instance.bip49,
      'bip44': instance.bip44,
      'bip84': instance.bip84,
    };

_$_ColdWallet _$$_ColdWalletFromJson(Map<String, dynamic> json) =>
    _$_ColdWallet(
      xpub: json['xpub'] as String?,
      first: json['first'] as String?,
      deriv: json['deriv'] as String?,
      xfp: json['xfp'] as String?,
      name: json['name'] as String?,
      sPub: json['_pub'] as String?,
    );

Map<String, dynamic> _$$_ColdWalletToJson(_$_ColdWallet instance) =>
    <String, dynamic>{
      'xpub': instance.xpub,
      'first': instance.first,
      'deriv': instance.deriv,
      'xfp': instance.xfp,
      'name': instance.name,
      '_pub': instance.sPub,
    };
