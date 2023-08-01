// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Wallet _$$_WalletFromJson(Map<String, dynamic> json) => _$_Wallet(
      id: json['id'] as String? ?? '',
      externalPublicDescriptor:
          json['externalPublicDescriptor'] as String? ?? '',
      internalPublicDescriptor:
          json['internalPublicDescriptor'] as String? ?? '',
      mnemonicFingerprint: json['mnemonicFingerprint'] as String? ?? '',
      sourceFingerprint: json['sourceFingerprint'] as String? ?? '',
      network: $enumDecode(_$BBNetworkEnumMap, json['network']),
      type: $enumDecode(_$BBWalletTypeEnumMap, json['type']),
      scriptType: $enumDecode(_$ScriptTypeEnumMap, json['scriptType']),
      name: json['name'] as String?,
      path: json['path'] as String?,
      balance: json['balance'] as int?,
      addresses: (json['addresses'] as List<dynamic>?)
          ?.map((e) => Address.fromJson(e as Map<String, dynamic>))
          .toList(),
      toAddresses: (json['toAddresses'] as List<dynamic>?)
          ?.map((e) => Address.fromJson(e as Map<String, dynamic>))
          .toList(),
      transactions: (json['transactions'] as List<dynamic>?)
          ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      labelTags: (json['labelTags'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      bip329Labels: (json['bip329Labels'] as List<dynamic>?)
          ?.map((e) => Bip329Label.fromJson(e as Map<String, dynamic>))
          .toList(),
      backupTested: json['backupTested'] as bool? ?? false,
      hide: json['hide'] as bool? ?? false,
    );

Map<String, dynamic> _$$_WalletToJson(_$_Wallet instance) => <String, dynamic>{
      'id': instance.id,
      'externalPublicDescriptor': instance.externalPublicDescriptor,
      'internalPublicDescriptor': instance.internalPublicDescriptor,
      'mnemonicFingerprint': instance.mnemonicFingerprint,
      'sourceFingerprint': instance.sourceFingerprint,
      'network': _$BBNetworkEnumMap[instance.network]!,
      'type': _$BBWalletTypeEnumMap[instance.type]!,
      'scriptType': _$ScriptTypeEnumMap[instance.scriptType]!,
      'name': instance.name,
      'path': instance.path,
      'balance': instance.balance,
      'addresses': instance.addresses,
      'toAddresses': instance.toAddresses,
      'transactions': instance.transactions,
      'labelTags': instance.labelTags,
      'bip329Labels': instance.bip329Labels,
      'backupTested': instance.backupTested,
      'hide': instance.hide,
    };

const _$BBNetworkEnumMap = {
  BBNetwork.Testnet: 'Testnet',
  BBNetwork.Mainnet: 'Mainnet',
};

const _$BBWalletTypeEnumMap = {
  BBWalletType.newSeed: 'newSeed',
  BBWalletType.xpub: 'xpub',
  BBWalletType.descriptors: 'descriptors',
  BBWalletType.words: 'words',
  BBWalletType.coldcard: 'coldcard',
};

const _$ScriptTypeEnumMap = {
  ScriptType.bip84: 'bip84',
  ScriptType.bip49: 'bip49',
  ScriptType.bip44: 'bip44',
};
