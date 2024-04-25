// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CurrencyStateImpl _$$CurrencyStateImplFromJson(Map<String, dynamic> json) =>
    _$CurrencyStateImpl(
      unitsInSats: json['unitsInSats'] as bool? ?? false,
      fiatSelected: json['fiatSelected'] as bool? ?? false,
      currency: json['currency'] == null
          ? null
          : Currency.fromJson(json['currency'] as Map<String, dynamic>),
      defaultFiatCurrency: json['defaultFiatCurrency'] == null
          ? null
          : Currency.fromJson(
              json['defaultFiatCurrency'] as Map<String, dynamic>),
      currencyList: (json['currencyList'] as List<dynamic>?)
          ?.map((e) => Currency.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastUpdatedCurrency: json['lastUpdatedCurrency'] == null
          ? null
          : DateTime.parse(json['lastUpdatedCurrency'] as String),
      loadingCurrency: json['loadingCurrency'] as bool? ?? false,
      errLoadingCurrency: json['errLoadingCurrency'] as String? ?? '',
      fiatAmt: (json['fiatAmt'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      tempAmount: json['tempAmount'] as String?,
      errAmount: json['errAmount'] as String? ?? '',
    );

Map<String, dynamic> _$$CurrencyStateImplToJson(_$CurrencyStateImpl instance) =>
    <String, dynamic>{
      'unitsInSats': instance.unitsInSats,
      'fiatSelected': instance.fiatSelected,
      'currency': instance.currency,
      'defaultFiatCurrency': instance.defaultFiatCurrency,
      'currencyList': instance.currencyList,
      'lastUpdatedCurrency': instance.lastUpdatedCurrency?.toIso8601String(),
      'loadingCurrency': instance.loadingCurrency,
      'errLoadingCurrency': instance.errLoadingCurrency,
      'fiatAmt': instance.fiatAmt,
      'amount': instance.amount,
      'tempAmount': instance.tempAmount,
      'errAmount': instance.errAmount,
    };
