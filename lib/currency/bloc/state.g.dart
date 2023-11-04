// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_CurrencyState _$$_CurrencyStateFromJson(Map<String, dynamic> json) =>
    _$_CurrencyState(
      unitsInSats: json['unitsInSats'] as bool? ?? false,
      fiatSelected: json['fiatSelected'] as bool? ?? false,
      currency: json['currency'] == null
          ? null
          : Currency.fromJson(json['currency'] as Map<String, dynamic>),
      currencyList: (json['currencyList'] as List<dynamic>?)
          ?.map((e) => Currency.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastUpdatedCurrency: json['lastUpdatedCurrency'] == null
          ? null
          : DateTime.parse(json['lastUpdatedCurrency'] as String),
      loadingCurrency: json['loadingCurrency'] as bool? ?? false,
      errLoadingCurrency: json['errLoadingCurrency'] as String? ?? '',
      fiatAmt: (json['fiatAmt'] as num?)?.toDouble() ?? 0,
      amount: json['amount'] as int? ?? 0,
      tempAmount: json['tempAmount'] as String?,
      errAmount: json['errAmount'] as String? ?? '',
    );

Map<String, dynamic> _$$_CurrencyStateToJson(_$_CurrencyState instance) =>
    <String, dynamic>{
      'unitsInSats': instance.unitsInSats,
      'fiatSelected': instance.fiatSelected,
      'currency': instance.currency,
      'currencyList': instance.currencyList,
      'lastUpdatedCurrency': instance.lastUpdatedCurrency?.toIso8601String(),
      'loadingCurrency': instance.loadingCurrency,
      'errLoadingCurrency': instance.errLoadingCurrency,
      'fiatAmt': instance.fiatAmt,
      'amount': instance.amount,
      'tempAmount': instance.tempAmount,
      'errAmount': instance.errAmount,
    };
