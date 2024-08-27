// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swap.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChainSwapDetailsImpl _$$ChainSwapDetailsImplFromJson(
        Map<String, dynamic> json) =>
    _$ChainSwapDetailsImpl(
      direction: $enumDecode(_$ChainSwapDirectionEnumMap, json['direction']),
      onChainType: $enumDecode(_$OnChainSwapTypeEnumMap, json['onChainType']),
      refundKeyIndex: (json['refundKeyIndex'] as num).toInt(),
      refundSecretKey: json['refundSecretKey'] as String,
      refundPublicKey: json['refundPublicKey'] as String,
      claimKeyIndex: (json['claimKeyIndex'] as num).toInt(),
      claimSecretKey: json['claimSecretKey'] as String,
      claimPublicKey: json['claimPublicKey'] as String,
      lockupLocktime: (json['lockupLocktime'] as num).toInt(),
      claimLocktime: (json['claimLocktime'] as num).toInt(),
      btcElectrumUrl: json['btcElectrumUrl'] as String,
      lbtcElectrumUrl: json['lbtcElectrumUrl'] as String,
      blindingKey: json['blindingKey'] as String,
      btcFundingAddress: json['btcFundingAddress'] as String,
      btcScriptSenderPublicKey: json['btcScriptSenderPublicKey'] as String,
      btcScriptReceiverPublicKey: json['btcScriptReceiverPublicKey'] as String,
      lbtcFundingAddress: json['lbtcFundingAddress'] as String,
      lbtcScriptSenderPublicKey: json['lbtcScriptSenderPublicKey'] as String,
      lbtcScriptReceiverPublicKey:
          json['lbtcScriptReceiverPublicKey'] as String,
      toWalletId: json['toWalletId'] as String,
    );

Map<String, dynamic> _$$ChainSwapDetailsImplToJson(
        _$ChainSwapDetailsImpl instance) =>
    <String, dynamic>{
      'direction': _$ChainSwapDirectionEnumMap[instance.direction]!,
      'onChainType': _$OnChainSwapTypeEnumMap[instance.onChainType]!,
      'refundKeyIndex': instance.refundKeyIndex,
      'refundSecretKey': instance.refundSecretKey,
      'refundPublicKey': instance.refundPublicKey,
      'claimKeyIndex': instance.claimKeyIndex,
      'claimSecretKey': instance.claimSecretKey,
      'claimPublicKey': instance.claimPublicKey,
      'lockupLocktime': instance.lockupLocktime,
      'claimLocktime': instance.claimLocktime,
      'btcElectrumUrl': instance.btcElectrumUrl,
      'lbtcElectrumUrl': instance.lbtcElectrumUrl,
      'blindingKey': instance.blindingKey,
      'btcFundingAddress': instance.btcFundingAddress,
      'btcScriptSenderPublicKey': instance.btcScriptSenderPublicKey,
      'btcScriptReceiverPublicKey': instance.btcScriptReceiverPublicKey,
      'lbtcFundingAddress': instance.lbtcFundingAddress,
      'lbtcScriptSenderPublicKey': instance.lbtcScriptSenderPublicKey,
      'lbtcScriptReceiverPublicKey': instance.lbtcScriptReceiverPublicKey,
      'toWalletId': instance.toWalletId,
    };

const _$ChainSwapDirectionEnumMap = {
  ChainSwapDirection.btcToLbtc: 'btcToLbtc',
  ChainSwapDirection.lbtcToBtc: 'lbtcToBtc',
};

const _$OnChainSwapTypeEnumMap = {
  OnChainSwapType.selfSwap: 'selfSwap',
  OnChainSwapType.receiveSwap: 'receiveSwap',
  OnChainSwapType.sendSwap: 'sendSwap',
};

_$LnSwapDetailsImpl _$$LnSwapDetailsImplFromJson(Map<String, dynamic> json) =>
    _$LnSwapDetailsImpl(
      swapType: $enumDecode(_$SwapTypeEnumMap, json['swapType']),
      invoice: json['invoice'] as String,
      boltzPubKey: json['boltzPubKey'] as String,
      keyIndex: (json['keyIndex'] as num).toInt(),
      myPublicKey: json['myPublicKey'] as String,
      sha256: json['sha256'] as String,
      electrumUrl: json['electrumUrl'] as String,
      locktime: (json['locktime'] as num).toInt(),
      hash160: json['hash160'] as String?,
      blindingKey: json['blindingKey'] as String?,
    );

Map<String, dynamic> _$$LnSwapDetailsImplToJson(_$LnSwapDetailsImpl instance) =>
    <String, dynamic>{
      'swapType': _$SwapTypeEnumMap[instance.swapType]!,
      'invoice': instance.invoice,
      'boltzPubKey': instance.boltzPubKey,
      'keyIndex': instance.keyIndex,
      'myPublicKey': instance.myPublicKey,
      'sha256': instance.sha256,
      'electrumUrl': instance.electrumUrl,
      'locktime': instance.locktime,
      'hash160': instance.hash160,
      'blindingKey': instance.blindingKey,
    };

const _$SwapTypeEnumMap = {
  SwapType.submarine: 'submarine',
  SwapType.reverse: 'reverse',
  SwapType.chain: 'chain',
};

_$SwapTxImpl _$$SwapTxImplFromJson(Map<String, dynamic> json) => _$SwapTxImpl(
      id: json['id'] as String,
      network: $enumDecode(_$BBNetworkEnumMap, json['network']),
      walletType: $enumDecode(_$BaseWalletTypeEnumMap, json['walletType']),
      outAmount: (json['outAmount'] as num).toInt(),
      scriptAddress: json['scriptAddress'] as String,
      boltzUrl: json['boltzUrl'] as String,
      chainSwapDetails: json['chainSwapDetails'] == null
          ? null
          : ChainSwapDetails.fromJson(
              json['chainSwapDetails'] as Map<String, dynamic>),
      lnSwapDetails: json['lnSwapDetails'] == null
          ? null
          : LnSwapDetails.fromJson(
              json['lnSwapDetails'] as Map<String, dynamic>),
      claimTxid: json['claimTxid'] as String?,
      lockupTxid: json['lockupTxid'] as String?,
      label: json['label'] as String?,
      status: json['status'] == null
          ? null
          : SwapStreamStatus.fromJson(json['status'] as Map<String, dynamic>),
      boltzFees: (json['boltzFees'] as num?)?.toInt(),
      lockupFees: (json['lockupFees'] as num?)?.toInt(),
      claimFees: (json['claimFees'] as num?)?.toInt(),
      claimAddress: json['claimAddress'] as String?,
      refundAddress: json['refundAddress'] as String?,
      creationTime: json['creationTime'] == null
          ? null
          : DateTime.parse(json['creationTime'] as String),
      completionTime: json['completionTime'] == null
          ? null
          : DateTime.parse(json['completionTime'] as String),
    );

Map<String, dynamic> _$$SwapTxImplToJson(_$SwapTxImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'network': _$BBNetworkEnumMap[instance.network]!,
      'walletType': _$BaseWalletTypeEnumMap[instance.walletType]!,
      'outAmount': instance.outAmount,
      'scriptAddress': instance.scriptAddress,
      'boltzUrl': instance.boltzUrl,
      'chainSwapDetails': instance.chainSwapDetails,
      'lnSwapDetails': instance.lnSwapDetails,
      'claimTxid': instance.claimTxid,
      'lockupTxid': instance.lockupTxid,
      'label': instance.label,
      'status': instance.status,
      'boltzFees': instance.boltzFees,
      'lockupFees': instance.lockupFees,
      'claimFees': instance.claimFees,
      'claimAddress': instance.claimAddress,
      'refundAddress': instance.refundAddress,
      'creationTime': instance.creationTime?.toIso8601String(),
      'completionTime': instance.completionTime?.toIso8601String(),
    };

const _$BBNetworkEnumMap = {
  BBNetwork.Testnet: 'Testnet',
  BBNetwork.Mainnet: 'Mainnet',
};

const _$BaseWalletTypeEnumMap = {
  BaseWalletType.Bitcoin: 'Bitcoin',
  BaseWalletType.Liquid: 'Liquid',
};

_$LnSwapTxSensitiveImpl _$$LnSwapTxSensitiveImplFromJson(
        Map<String, dynamic> json) =>
    _$LnSwapTxSensitiveImpl(
      id: json['id'] as String,
      secretKey: json['secretKey'] as String,
      publicKey: json['publicKey'] as String,
      preimage: json['preimage'] as String,
      sha256: json['sha256'] as String,
      hash160: json['hash160'] as String,
      boltzPubkey: json['boltzPubkey'] as String?,
      isSubmarine: json['isSubmarine'] as bool?,
      scriptAddress: json['scriptAddress'] as String?,
      locktime: (json['locktime'] as num?)?.toInt(),
      blindingKey: json['blindingKey'] as String?,
    );

Map<String, dynamic> _$$LnSwapTxSensitiveImplToJson(
        _$LnSwapTxSensitiveImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'secretKey': instance.secretKey,
      'publicKey': instance.publicKey,
      'preimage': instance.preimage,
      'sha256': instance.sha256,
      'hash160': instance.hash160,
      'boltzPubkey': instance.boltzPubkey,
      'isSubmarine': instance.isSubmarine,
      'scriptAddress': instance.scriptAddress,
      'locktime': instance.locktime,
      'blindingKey': instance.blindingKey,
    };

_$ChainSwapTxSensitiveImpl _$$ChainSwapTxSensitiveImplFromJson(
        Map<String, dynamic> json) =>
    _$ChainSwapTxSensitiveImpl(
      id: json['id'] as String,
      refundKeySecret: json['refundKeySecret'] as String,
      claimKeySecret: json['claimKeySecret'] as String,
      preimage: json['preimage'] as String,
      sha256: json['sha256'] as String,
      hash160: json['hash160'] as String,
      blindingKey: json['blindingKey'] as String,
    );

Map<String, dynamic> _$$ChainSwapTxSensitiveImplToJson(
        _$ChainSwapTxSensitiveImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'refundKeySecret': instance.refundKeySecret,
      'claimKeySecret': instance.claimKeySecret,
      'preimage': instance.preimage,
      'sha256': instance.sha256,
      'hash160': instance.hash160,
      'blindingKey': instance.blindingKey,
    };

_$InvoiceImpl _$$InvoiceImplFromJson(Map<String, dynamic> json) =>
    _$InvoiceImpl(
      msats: (json['msats'] as num).toInt(),
      expiry: (json['expiry'] as num).toInt(),
      expiresIn: (json['expiresIn'] as num).toInt(),
      expiresAt: (json['expiresAt'] as num).toInt(),
      isExpired: json['isExpired'] as bool,
      network: json['network'] as String,
      cltvExpDelta: (json['cltvExpDelta'] as num).toInt(),
      invoice: json['invoice'] as String,
      bip21: json['bip21'] as String?,
    );

Map<String, dynamic> _$$InvoiceImplToJson(_$InvoiceImpl instance) =>
    <String, dynamic>{
      'msats': instance.msats,
      'expiry': instance.expiry,
      'expiresIn': instance.expiresIn,
      'expiresAt': instance.expiresAt,
      'isExpired': instance.isExpired,
      'network': instance.network,
      'cltvExpDelta': instance.cltvExpDelta,
      'invoice': instance.invoice,
      'bip21': instance.bip21,
    };
