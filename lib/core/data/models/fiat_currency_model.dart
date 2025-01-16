import 'package:freezed_annotation/freezed_annotation.dart';

part 'fiat_currency_model.freezed.dart';

@freezed
class FiatCurrencyModel with _$FiatCurrencyModel {
  const factory FiatCurrencyModel({
    required String name,
    required String code,
  }) = _FiatCurrencyModel;
  const FiatCurrencyModel._();

  factory FiatCurrencyModel.fromJson(Map<String, dynamic> json) =>
      _$FiatCurrencyModelFromJson(json);
}
