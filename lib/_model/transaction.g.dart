// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TransactionImpl _$$TransactionImplFromJson(Map<String, dynamic> json) =>
    _$TransactionImpl(
      timestamp: json['timestamp'] as int,
      txid: json['txid'] as String,
      received: json['received'] as int?,
      sent: json['sent'] as int?,
      fee: json['fee'] as int?,
      height: json['height'] as int?,
      label: json['label'] as String?,
      toAddress: json['toAddress'] as String?,
      psbt: json['psbt'] as String?,
      rbfEnabled: json['rbfEnabled'] as bool? ?? true,
      oldTx: json['oldTx'] as bool? ?? false,
      broadcastTime: json['broadcastTime'] as int?,
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
    };

_$SwapTxImpl _$$SwapTxImplFromJson(Map<String, dynamic> json) => _$SwapTxImpl(
      id: json['id'] as String,
      txid: json['txid'] as String?,
      keyIndex: json['keyIndex'] as int?,
      isSubmarine: json['isSubmarine'] as bool,
      network: $enumDecode(_$BBNetworkEnumMap, json['network']),
      secretKey: json['secretKey'] as String?,
      publicKey: json['publicKey'] as String?,
      sha256: json['sha256'] as String?,
      hash160: json['hash160'] as String?,
      redeemScript: json['redeemScript'] as String,
      invoice: json['invoice'] as String,
      outAmount: json['outAmount'] as int,
      scriptAddress: json['scriptAddress'] as String,
      electrumUrl: json['electrumUrl'] as String,
      boltzUrl: json['boltzUrl'] as String,
      status: json['status'] == null
          ? null
          : SwapStatusResponse.fromJson(json['status'] as Map<String, dynamic>),
      blindingKey: json['blindingKey'] as String?,
    );

Map<String, dynamic> _$$SwapTxImplToJson(_$SwapTxImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'txid': instance.txid,
      'keyIndex': instance.keyIndex,
      'isSubmarine': instance.isSubmarine,
      'network': _$BBNetworkEnumMap[instance.network]!,
      'secretKey': instance.secretKey,
      'publicKey': instance.publicKey,
      'sha256': instance.sha256,
      'hash160': instance.hash160,
      'redeemScript': instance.redeemScript,
      'invoice': instance.invoice,
      'outAmount': instance.outAmount,
      'scriptAddress': instance.scriptAddress,
      'electrumUrl': instance.electrumUrl,
      'boltzUrl': instance.boltzUrl,
      'status': instance.status,
      'blindingKey': instance.blindingKey,
    };

const _$BBNetworkEnumMap = {
  BBNetwork.Testnet: 'Testnet',
  BBNetwork.Mainnet: 'Mainnet',
  BBNetwork.LTestnet: 'LTestnet',
  BBNetwork.LMainnet: 'LMainnet',
};

_$SwapTxSensitiveImpl _$$SwapTxSensitiveImplFromJson(
        Map<String, dynamic> json) =>
    _$SwapTxSensitiveImpl(
      id: json['id'] as String,
      secretKey: json['secretKey'] as String,
      publicKey: json['publicKey'] as String,
      value: json['value'] as String,
      sha256: json['sha256'] as String,
      hash160: json['hash160'] as String,
    );

Map<String, dynamic> _$$SwapTxSensitiveImplToJson(
        _$SwapTxSensitiveImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'secretKey': instance.secretKey,
      'publicKey': instance.publicKey,
      'value': instance.value,
      'sha256': instance.sha256,
      'hash160': instance.hash160,
    };
