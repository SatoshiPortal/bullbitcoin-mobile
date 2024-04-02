// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WalletImpl _$$WalletImplFromJson(Map<String, dynamic> json) => _$WalletImpl(
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
      utxos: (json['utxos'] as List<dynamic>?)
              ?.map((e) => UTXO.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      unsignedTxs: (json['unsignedTxs'] as List<dynamic>?)
              ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      swaps: (json['swaps'] as List<dynamic>?)
              ?.map((e) => SwapTx.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      revKeyIndex: json['revKeyIndex'] as int? ?? 0,
      subKeyIndex: json['subKeyIndex'] as int? ?? 0,
      backupTested: json['backupTested'] as bool? ?? false,
      lastBackupTested: json['lastBackupTested'] == null
          ? null
          : DateTime.parse(json['lastBackupTested'] as String),
      hide: json['hide'] as bool? ?? false,
      mainWallet: json['mainWallet'] as bool? ?? false,
    );

Map<String, dynamic> _$$WalletImplToJson(_$WalletImpl instance) =>
    <String, dynamic>{
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
      'utxos': instance.utxos,
      'transactions': instance.transactions,
      'unsignedTxs': instance.unsignedTxs,
      'swaps': instance.swaps,
      'revKeyIndex': instance.revKeyIndex,
      'subKeyIndex': instance.subKeyIndex,
      'backupTested': instance.backupTested,
      'lastBackupTested': instance.lastBackupTested?.toIso8601String(),
      'hide': instance.hide,
      'mainWallet': instance.mainWallet,
    };

const _$BBNetworkEnumMap = {
  BBNetwork.Testnet: 'Testnet',
  BBNetwork.Mainnet: 'Mainnet',
  BBNetwork.LTestnet: 'LTestnet',
  BBNetwork.LMainnet: 'LMainnet',
};

const _$BBWalletTypeEnumMap = {
  BBWalletType.secure: 'secure',
  BBWalletType.xpub: 'xpub',
  BBWalletType.descriptors: 'descriptors',
  BBWalletType.words: 'words',
  BBWalletType.coldcard: 'coldcard',
  BBWalletType.instant: 'instant',
};

const _$ScriptTypeEnumMap = {
  ScriptType.bip84: 'bip84',
  ScriptType.bip49: 'bip49',
  ScriptType.bip44: 'bip44',
};

_$BalanceImpl _$$BalanceImplFromJson(Map<String, dynamic> json) =>
    _$BalanceImpl(
      immature: json['immature'] as int,
      trustedPending: json['trustedPending'] as int,
      untrustedPending: json['untrustedPending'] as int,
      confirmed: json['confirmed'] as int,
      spendable: json['spendable'] as int,
      total: json['total'] as int,
    );

Map<String, dynamic> _$$BalanceImplToJson(_$BalanceImpl instance) =>
    <String, dynamic>{
      'immature': instance.immature,
      'trustedPending': instance.trustedPending,
      'untrustedPending': instance.untrustedPending,
      'confirmed': instance.confirmed,
      'spendable': instance.spendable,
      'total': instance.total,
    };
