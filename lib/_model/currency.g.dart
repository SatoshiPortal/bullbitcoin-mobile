// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Currency _$$_CurrencyFromJson(Map<String, dynamic> json) => _$_Currency(
      name: json['name'] as String,
      price: (json['price'] as num?)?.toDouble(),
      shortName: json['shortName'] as String,
    );

Map<String, dynamic> _$$_CurrencyToJson(_$_Currency instance) =>
    <String, dynamic>{
      'name': instance.name,
      'price': instance.price,
      'shortName': instance.shortName,
    };
