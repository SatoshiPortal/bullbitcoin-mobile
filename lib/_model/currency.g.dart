// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CurrencyImpl _$$CurrencyImplFromJson(Map<String, dynamic> json) =>
    _$CurrencyImpl(
      name: json['name'] as String,
      price: (json['price'] as num?)?.toDouble(),
      shortName: json['shortName'] as String,
    );

Map<String, dynamic> _$$CurrencyImplToJson(_$CurrencyImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'price': instance.price,
      'shortName': instance.shortName,
    };
