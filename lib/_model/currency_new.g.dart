// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency_new.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CurrencyNewImpl _$$CurrencyNewImplFromJson(Map<String, dynamic> json) =>
    _$CurrencyNewImpl(
      name: json['name'] as String,
      price: (json['price'] as num?)?.toDouble(),
      code: json['code'] as String,
      isFiat: json['isFiat'] as bool,
    );

Map<String, dynamic> _$$CurrencyNewImplToJson(_$CurrencyNewImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'price': instance.price,
      'code': instance.code,
      'isFiat': instance.isFiat,
    };
