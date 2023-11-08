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
      fullBalance: json['fullBalance'] == null
          ? null
          : Balance.fromJson(json['fullBalance'] as Map<String, dynamic>),
      lastGeneratedAddress: json['lastGeneratedAddress'] == null
          ? null
          : Address.fromJson(
              json['lastGeneratedAddress'] as Map<String, dynamic>),
      myAddressBook: (json['myAddressBook'] as List<dynamic>?)
              ?.map((e) => Address.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      externalAddressBook: (json['externalAddressBook'] as List<dynamic>?)
          ?.map((e) => Address.fromJson(e as Map<String, dynamic>))
          .toList(),
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      unsignedTxs: (json['unsignedTxs'] as List<dynamic>?)
              ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      backupTested: json['backupTested'] as bool? ?? false,
      lastBackupTested: json['lastBackupTested'] == null
          ? null
          : DateTime.parse(json['lastBackupTested'] as String),
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
      'fullBalance': instance.fullBalance,
      'lastGeneratedAddress': instance.lastGeneratedAddress,
      'myAddressBook': instance.myAddressBook,
      'externalAddressBook': instance.externalAddressBook,
      'transactions': instance.transactions,
      'unsignedTxs': instance.unsignedTxs,
      'backupTested': instance.backupTested,
      'lastBackupTested': instance.lastBackupTested?.toIso8601String(),
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

_$_Balance _$$_BalanceFromJson(Map<String, dynamic> json) => _$_Balance(
      immature: json['immature'] as int,
      trustedPending: json['trustedPending'] as int,
      untrustedPending: json['untrustedPending'] as int,
      confirmed: json['confirmed'] as int,
      spendable: json['spendable'] as int,
      total: json['total'] as int,
    );

Map<String, dynamic> _$$_BalanceToJson(_$_Balance instance) =>
    <String, dynamic>{
      'immature': instance.immature,
      'trustedPending': instance.trustedPending,
      'untrustedPending': instance.untrustedPending,
      'confirmed': instance.confirmed,
      'spendable': instance.spendable,
      'total': instance.total,
    };
