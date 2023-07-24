// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet2.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Wallet _$$_WalletFromJson(Map<String, dynamic> json) => _$_Wallet(
      walletHashId: json['walletHashId'] as String,
      externalPublicDescriptor: json['externalPublicDescriptor'] as String,
      internalPublicDescriptor: json['internalPublicDescriptor'] as String,
      xpub: json['xpub'] as String?,
      mnemonicFingerprint: json['mnemonicFingerprint'] as String,
      sourceFingerprint: json['sourceFingerprint'] as String,
      network: $enumDecode(_$BBNetworkEnumMap, json['network']),
      type: $enumDecode(_$BBWalletTypeEnumMap, json['type']),
      purpose: $enumDecode(_$WalletPurposeEnumMap, json['purpose']),
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
      backupTested: json['backupTested'] as bool? ?? false,
      hide: json['hide'] as bool? ?? false,
    );

Map<String, dynamic> _$$_WalletToJson(_$_Wallet instance) => <String, dynamic>{
      'walletHashId': instance.walletHashId,
      'externalPublicDescriptor': instance.externalPublicDescriptor,
      'internalPublicDescriptor': instance.internalPublicDescriptor,
      'xpub': instance.xpub,
      'mnemonicFingerprint': instance.mnemonicFingerprint,
      'sourceFingerprint': instance.sourceFingerprint,
      'network': _$BBNetworkEnumMap[instance.network]!,
      'type': _$BBWalletTypeEnumMap[instance.type]!,
      'purpose': _$WalletPurposeEnumMap[instance.purpose]!,
      'name': instance.name,
      'path': instance.path,
      'balance': instance.balance,
      'addresses': instance.addresses,
      'toAddresses': instance.toAddresses,
      'transactions': instance.transactions,
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

const _$WalletPurposeEnumMap = {
  WalletPurpose.bip84: 'bip84',
  WalletPurpose.bip49: 'bip49',
  WalletPurpose.bip44: 'bip44',
};
