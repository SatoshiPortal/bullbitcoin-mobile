// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/core/exchange/domain/entity/funding_details.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'funding_details_model.freezed.dart';
part 'funding_details_model.g.dart';

@freezed
sealed class FundingDetailsModel with _$FundingDetailsModel {
  const factory FundingDetailsModel({
    required String code,
    @JsonKey(name: 'IBAN') String? iban,
    @JsonKey(name: 'BIC') String? bic,
    @JsonKey(name: 'BENEFICIARY NAME') String? beneficiaryName,
    @JsonKey(name: 'BENEFICIARY ADDRESS') String? beneficiaryAddress,
    @JsonKey(name: 'BANK ACCOUNT COUNTRY') String? bankAccountCountry,
  }) = _FundingDetailsModel;
  const FundingDetailsModel._();

  factory FundingDetailsModel.fromJson(Map<String, dynamic> json) =>
      _$FundingDetailsModelFromJson(json);

  FundingDetails toEntity() {
    return FundingDetails.eTransfer(code: code);
  }
}
