import 'package:freezed_annotation/freezed_annotation.dart';

part 'funding_details_request_params_model.freezed.dart';
part 'funding_details_request_params_model.g.dart';

@freezed
sealed class FundingDetailsRequestParamsModel
    with _$FundingDetailsRequestParamsModel {
  const factory FundingDetailsRequestParamsModel({
    required String jurisdiction,
    required String paymentMethod,
    required int? amount,
  }) = _FundingDetailsRequestParamsModel;

  factory FundingDetailsRequestParamsModel.fromJson(
    Map<String, dynamic> json,
  ) => _$FundingDetailsRequestParamsModelFromJson(json);
}
