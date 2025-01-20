import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'fiat_currency_model.freezed.dart';
part 'fiat_currency_model.g.dart';

@freezed
class FiatCurrencyModel with _$FiatCurrencyModel {
  const factory FiatCurrencyModel({
    required String name,
    required String code,
  }) = _FiatCurrencyModel;
  const FiatCurrencyModel._();

  factory FiatCurrencyModel.fromJson(Map<String, Object?> json) =>
      _$FiatCurrencyModelFromJson(json);
}
