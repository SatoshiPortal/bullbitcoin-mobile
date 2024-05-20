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
      height: (json['height'] as num?)?.toInt(),
      label: json['label'] as String?,
      toAddress: json['toAddress'] as String?,
      psbt: json['psbt'] as String?,
      rbfEnabled: json['rbfEnabled'] as bool? ?? true,
      oldTx: json['oldTx'] as bool? ?? false,
      broadcastTime: (json['broadcastTime'] as num?)?.toInt(),
      outAddrs: (json['outAddrs'] as List<dynamic>?)
              ?.map((e) => Address.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      wallet: json['wallet'] == null
          ? null
          : Wallet.fromJson(json['wallet'] as Map<String, dynamic>),
      isSwap: json['isSwap'] as bool? ?? false,
      swapTx: json['swapTx'] == null
          ? null
          : SwapTx.fromJson(json['swapTx'] as Map<String, dynamic>),
      isLiquid: json['isLiquid'] as bool? ?? false,
    );

Map<String, dynamic> _$$TransactionImplToJson(_$TransactionImpl instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp,
      'txid': instance.txid,
      'received': instance.received,
      'sent': instance.sent,
      'fee': instance.fee,
      'height': instance.height,
      'label': instance.label,
      'toAddress': instance.toAddress,
      'psbt': instance.psbt,
      'rbfEnabled': instance.rbfEnabled,
      'oldTx': instance.oldTx,
      'broadcastTime': instance.broadcastTime,
      'outAddrs': instance.outAddrs,
      'wallet': instance.wallet,
      'isSwap': instance.isSwap,
      'swapTx': instance.swapTx,
      'isLiquid': instance.isLiquid,
    };

_$SwapTxImpl _$$SwapTxImplFromJson(Map<String, dynamic> json) => _$SwapTxImpl(
      id: json['id'] as String,
      txid: json['txid'] as String?,
      keyIndex: (json['keyIndex'] as num?)?.toInt(),
      isSubmarine: json['isSubmarine'] as bool,
      network: $enumDecode(_$BBNetworkEnumMap, json['network']),
      walletType: $enumDecode(_$BaseWalletTypeEnumMap, json['walletType']),
      secretKey: json['secretKey'] as String?,
      publicKey: json['publicKey'] as String?,
      sha256: json['sha256'] as String?,
      hash160: json['hash160'] as String?,
      redeemScript: json['redeemScript'] as String,
      boltzPubkey: json['boltzPubkey'] as String?,
      locktime: (json['locktime'] as num?)?.toInt(),
      invoice: json['invoice'] as String,
      outAmount: (json['outAmount'] as num).toInt(),
      scriptAddress: json['scriptAddress'] as String,
      electrumUrl: json['electrumUrl'] as String,
      boltzUrl: json['boltzUrl'] as String,
      status: json['status'] == null
          ? null
          : SwapStreamStatus.fromJson(json['status'] as Map<String, dynamic>),
      blindingKey: json['blindingKey'] as String?,
      boltzFees: (json['boltzFees'] as num?)?.toInt(),
      lockupFees: (json['lockupFees'] as num?)?.toInt(),
      claimFees: (json['claimFees'] as num?)?.toInt(),
      claimAddress: json['claimAddress'] as String?,
    );

Map<String, dynamic> _$$SwapTxImplToJson(_$SwapTxImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'txid': instance.txid,
      'keyIndex': instance.keyIndex,
      'isSubmarine': instance.isSubmarine,
      'network': _$BBNetworkEnumMap[instance.network]!,
      'walletType': _$BaseWalletTypeEnumMap[instance.walletType]!,
      'secretKey': instance.secretKey,
      'publicKey': instance.publicKey,
      'sha256': instance.sha256,
      'hash160': instance.hash160,
      'redeemScript': instance.redeemScript,
      'boltzPubkey': instance.boltzPubkey,
      'locktime': instance.locktime,
      'invoice': instance.invoice,
      'outAmount': instance.outAmount,
      'scriptAddress': instance.scriptAddress,
      'electrumUrl': instance.electrumUrl,
      'boltzUrl': instance.boltzUrl,
      'status': instance.status,
      'blindingKey': instance.blindingKey,
      'boltzFees': instance.boltzFees,
      'lockupFees': instance.lockupFees,
      'claimFees': instance.claimFees,
      'claimAddress': instance.claimAddress,
    };

const _$BBNetworkEnumMap = {
  BBNetwork.Testnet: 'Testnet',
  BBNetwork.Mainnet: 'Mainnet',
};

const _$BaseWalletTypeEnumMap = {
  BaseWalletType.Bitcoin: 'Bitcoin',
  BaseWalletType.Liquid: 'Liquid',
};

_$SwapTxSensitiveImpl _$$SwapTxSensitiveImplFromJson(
        Map<String, dynamic> json) =>
    _$SwapTxSensitiveImpl(
      id: json['id'] as String,
      secretKey: json['secretKey'] as String,
      publicKey: json['publicKey'] as String,
      preimage: json['preimage'] as String,
      sha256: json['sha256'] as String,
      hash160: json['hash160'] as String,
      redeemScript: json['redeemScript'] as String,
      boltzPubkey: json['boltzPubkey'] as String?,
      isSubmarine: json['isSubmarine'] as bool?,
      scriptAddress: json['scriptAddress'] as String?,
      locktime: (json['locktime'] as num?)?.toInt(),
      blindingKey: json['blindingKey'] as String?,
    );

Map<String, dynamic> _$$SwapTxSensitiveImplToJson(
        _$SwapTxSensitiveImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'secretKey': instance.secretKey,
      'publicKey': instance.publicKey,
      'preimage': instance.preimage,
      'sha256': instance.sha256,
      'hash160': instance.hash160,
      'redeemScript': instance.redeemScript,
      'boltzPubkey': instance.boltzPubkey,
      'isSubmarine': instance.isSubmarine,
      'scriptAddress': instance.scriptAddress,
      'locktime': instance.locktime,
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
