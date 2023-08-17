// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Address _$$_AddressFromJson(Map<String, dynamic> json) => _$_Address(
      address: json['address'] as String,
      index: json['index'] as int,
      label: json['label'] as String?,
      sentTxId: json['sentTxId'] as String?,
      isReceive: json['isReceive'] as bool?,
      saving: json['saving'] as bool? ?? false,
      errSaving: json['errSaving'] as String? ?? '',
      unspendable: json['unspendable'] as bool? ?? false,
      isMine: json['isMine'] as bool? ?? true,
      highestPreviousBalance: json['highestPreviousBalance'] as int? ?? 0,
    );

Map<String, dynamic> _$$_AddressToJson(_$_Address instance) =>
    <String, dynamic>{
      'address': instance.address,
      'index': instance.index,
      'label': instance.label,
      'sentTxId': instance.sentTxId,
      'isReceive': instance.isReceive,
      'saving': instance.saving,
      'errSaving': instance.errSaving,
      'unspendable': instance.unspendable,
      'isMine': instance.isMine,
      'highestPreviousBalance': instance.highestPreviousBalance,
    };
