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
