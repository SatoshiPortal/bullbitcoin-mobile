import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'fiat_currency_model.freezed.dart';

@freezed
class FiatCurrencyModel with _$FiatCurrencyModel {
  const factory FiatCurrencyModel({
    required String name,
    required String code,
  }) = _FiatCurrencyModel;

  factory FiatCurrencyModel.fromJson(Map<String, Object?> json) =>
      _$FiatCurrencyModelFromJson(json);
}
