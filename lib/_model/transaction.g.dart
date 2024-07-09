// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TransactionImpl _$$TransactionImplFromJson(Map<String, dynamic> json) =>
    _$TransactionImpl(
      timestamp: (json['timestamp'] as num).toInt(),
      txid: json['txid'] as String,
      received: (json['received'] as num?)?.toInt(),
      sent: (json['sent'] as num?)?.toInt(),
      fee: (json['fee'] as num?)?.toInt(),
      feeRate: (json['feeRate'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toInt(),
      label: json['label'] as String?,
      toAddress: json['toAddress'] as String?,
      psbt: json['psbt'] as String?,
      rbfEnabled: json['rbfEnabled'] as bool? ?? true,
      broadcastTime: (json['broadcastTime'] as num?)?.toInt(),
      outAddrs: (json['outAddrs'] as List<dynamic>?)
              ?.map((e) => Address.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      inputs: (json['inputs'] as List<dynamic>?)
              ?.map((e) => TxIn.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isSwap: json['isSwap'] as bool? ?? false,
      swapTx: json['swapTx'] == null
          ? null
          : SwapTx.fromJson(json['swapTx'] as Map<String, dynamic>),
      isLiquid: json['isLiquid'] as bool? ?? false,
      unblindedUrl: json['unblindedUrl'] as String? ?? '',
      rbfTxIds: (json['rbfTxIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      walletId: json['walletId'] as String?,
    );

Map<String, dynamic> _$$TransactionImplToJson(_$TransactionImpl instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp,
      'txid': instance.txid,
      'received': instance.received,
      'sent': instance.sent,
      'fee': instance.fee,
      'feeRate': instance.feeRate,
      'height': instance.height,
      'label': instance.label,
      'toAddress': instance.toAddress,
      'psbt': instance.psbt,
      'rbfEnabled': instance.rbfEnabled,
      'broadcastTime': instance.broadcastTime,
      'outAddrs': instance.outAddrs,
      'inputs': instance.inputs,
      'isSwap': instance.isSwap,
      'swapTx': instance.swapTx,
      'isLiquid': instance.isLiquid,
      'unblindedUrl': instance.unblindedUrl,
      'rbfTxIds': instance.rbfTxIds,
      'walletId': instance.walletId,
    };

_$TxInImpl _$$TxInImplFromJson(Map<String, dynamic> json) => _$TxInImpl(
      prevOut: json['prevOut'] as String,
    );

Map<String, dynamic> _$$TxInImplToJson(_$TxInImpl instance) =>
    <String, dynamic>{
      'prevOut': instance.prevOut,
    };

_$ChainSwapDetailsImpl _$$ChainSwapDetailsImplFromJson(
        Map<String, dynamic> json) =>
    _$ChainSwapDetailsImpl(
      direction: $enumDecode(_$ChainSwapDirectionEnumMap, json['direction']),
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
      btcScriptSenderPublicKey: json['btcScriptSenderPublicKey'] as String,
      btcScriptReceiverPublicKey: json['btcScriptReceiverPublicKey'] as String,
      lbtcScriptSenderPublicKey: json['lbtcScriptSenderPublicKey'] as String,
      lbtcScriptReceiverPublicKey:
          json['lbtcScriptReceiverPublicKey'] as String,
    );

Map<String, dynamic> _$$ChainSwapDetailsImplToJson(
        _$ChainSwapDetailsImpl instance) =>
    <String, dynamic>{
      'direction': _$ChainSwapDirectionEnumMap[instance.direction]!,
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
      'btcScriptSenderPublicKey': instance.btcScriptSenderPublicKey,
      'btcScriptReceiverPublicKey': instance.btcScriptReceiverPublicKey,
      'lbtcScriptSenderPublicKey': instance.lbtcScriptSenderPublicKey,
      'lbtcScriptReceiverPublicKey': instance.lbtcScriptReceiverPublicKey,
    };

const _$ChainSwapDirectionEnumMap = {
  ChainSwapDirection.btcToLbtc: 'btcToLbtc',
  ChainSwapDirection.lbtcToBtc: 'lbtcToBtc',
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
      baseWalletType:
          $enumDecode(_$BaseWalletTypeEnumMap, json['baseWalletType']),
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
      txid: json['txid'] as String?,
      label: json['label'] as String?,
      status: json['status'] == null
          ? null
          : SwapStreamStatus.fromJson(json['status'] as Map<String, dynamic>),
      boltzFees: (json['boltzFees'] as num?)?.toInt(),
      lockupFees: (json['lockupFees'] as num?)?.toInt(),
      claimFees: (json['claimFees'] as num?)?.toInt(),
      claimAddress: json['claimAddress'] as String?,
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
      'baseWalletType': _$BaseWalletTypeEnumMap[instance.baseWalletType]!,
      'outAmount': instance.outAmount,
      'scriptAddress': instance.scriptAddress,
      'boltzUrl': instance.boltzUrl,
      'chainSwapDetails': instance.chainSwapDetails,
      'lnSwapDetails': instance.lnSwapDetails,
      'txid': instance.txid,
      'label': instance.label,
      'status': instance.status,
      'boltzFees': instance.boltzFees,
      'lockupFees': instance.lockupFees,
      'claimFees': instance.claimFees,
      'claimAddress': instance.claimAddress,
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
