// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Wallet _$$_WalletFromJson(Map<String, dynamic> json) => _$_Wallet(
      externalDescriptor: json['externalDescriptor'] as String? ?? '',
      internalDescriptor: json['internalDescriptor'] as String? ?? '',
      mnemonic: json['mnemonic'] as String? ?? '',
      password: json['password'] as String?,
      xpub: json['xpub'] as String?,
      fingerprint: json['fingerprint'] as String? ?? '',
      network: $enumDecode(_$BBNetworkEnumMap, json['network']),
      type: $enumDecode(_$BBWalletTypeEnumMap, json['type']),
      walletType: $enumDecode(_$WalletTypeEnumMap, json['walletType']),
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
    );

Map<String, dynamic> _$$_WalletToJson(_$_Wallet instance) => <String, dynamic>{
      'externalDescriptor': instance.externalDescriptor,
      'internalDescriptor': instance.internalDescriptor,
      'mnemonic': instance.mnemonic,
      'password': instance.password,
      'xpub': instance.xpub,
      'fingerprint': instance.fingerprint,
      'network': _$BBNetworkEnumMap[instance.network]!,
      'type': _$BBWalletTypeEnumMap[instance.type]!,
      'walletType': _$WalletTypeEnumMap[instance.walletType]!,
      'name': instance.name,
      'path': instance.path,
      'balance': instance.balance,
      'addresses': instance.addresses,
      'toAddresses': instance.toAddresses,
      'transactions': instance.transactions,
      'backupTested': instance.backupTested,
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

const _$WalletTypeEnumMap = {
  WalletType.bip84: 'bip84',
  WalletType.bip49: 'bip49',
  WalletType.bip44: 'bip44',
};
