// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/core/exchange/domain/entity/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'funding_details_model.freezed.dart';
part 'funding_details_model.g.dart';

@freezed
sealed class FundingDetailsModel with _$FundingDetailsModel {
  const factory FundingDetailsModel({
    String? code,
    String? userNbr,
    @JsonKey(name: 'BENEFICIARY NAME') String? beneficiaryName,
    @JsonKey(name: 'BENEFICIARY EMAIL') String? beneficiaryEmail,
    @JsonKey(name: 'BANK ACCOUNT DETAILS') String? bankAccountDetails,
    @JsonKey(name: 'IBAN') String? iban,
    @JsonKey(name: 'SWIFT') String? swift,
    @JsonKey(name: 'INSTITUTION NUMBER') String? institutionNumber,
    @JsonKey(name: 'TRANSIT NUMBER') String? transitNumber,
    @JsonKey(name: 'ACCOUNT NUMBER') String? accountNumber,
    @JsonKey(name: 'ROUTING NUMBER') String? routingNumber,
    @JsonKey(name: 'BENEFICIARY ADDRESS') String? beneficiaryAddress,
    @JsonKey(name: 'BANK ADDRESS') String? bankAddress,
    @JsonKey(name: 'BANK NAME') String? bankName,
    @JsonKey(name: 'BILLER NAME') String? billerName,
    @JsonKey(name: 'BIC') String? bic,
    @JsonKey(name: 'BANK ACCOUNT COUNTRY') String? bankAccountCountry,
    @JsonKey(name: 'BANK COUNTRY') String? bankCountry,
    @JsonKey(name: 'CLABE') String? clabe,
    @JsonKey(name: 'CÉDULA JURÍDICA') String? cedulaJuridica,
    @JsonKey(name: 'CVU') String? cvu,
  }) = _FundingDetailsModel;
  const FundingDetailsModel._();

  factory FundingDetailsModel.fromJson(Map<String, dynamic> json) =>
      _$FundingDetailsModelFromJson(json);

  FundingDetails toEntity({required FundingMethod method}) {
    // We don't check for nullability on the fields here because the API
    //  guarantees that these fields will be present for the respective funding
    //  methods and if not, something is wrong, and we want it to throw an error.
    switch (method) {
      case FundingMethod.emailETransfer:
        return FundingDetails.eTransfer(
          secretQuestion: code!,
          beneficiaryName: beneficiaryName!,
          beneficiaryEmail: beneficiaryEmail!,
        );
      case FundingMethod.bankTransferWire:
        return FundingDetails.wire(
          code: code!,
          beneficiaryName: beneficiaryName!,
          bankAccountDetails: bankAccountDetails!,
          iban: iban!,
          swift: swift!,
          institutionNumber: institutionNumber!,
          transitNumber: transitNumber!,
          accountNumber: accountNumber!,
          routingNumber: routingNumber!,
          beneficiaryAddress: beneficiaryAddress!,
          bankAddress: bankAddress!,
          bankName: bankName!,
        );
      case FundingMethod.onlineBillPayment:
        return FundingDetails.billPayment(code: code!, billerName: billerName!);
      case FundingMethod.canadaPost:
        return FundingDetails.canadaPost(code: code!);
      case FundingMethod.instantSepa:
        return FundingDetails.instantSepa(
          code: code!,
          iban: iban!,
          bic: bic!,
          beneficiaryName: beneficiaryName!,
          beneficiaryAddress: beneficiaryAddress!,
          bankAccountCountry: bankAccountCountry!,
        );
      case FundingMethod.regularSepa:
        return FundingDetails.regularSepa(
          code: code!,
          iban: iban!,
          bic: bic!,
          beneficiaryName: beneficiaryName!,
          beneficiaryAddress: beneficiaryAddress!,
          bankCountry: bankCountry!,
        );
      case FundingMethod.speiTransfer:
        return FundingDetails.spei(
          code: code!,
          bankName: bankName!,
          beneficiaryName: beneficiaryName!,
          clabe: clabe!,
        );
      case FundingMethod.sinpeTransfer:
        // TODO: Handle this case.
        throw UnimplementedError();
      case FundingMethod.crIbanCrc:
        return FundingDetails.crIbanCrc(
          iban: iban!,
          code: code!,
          beneficiaryName: beneficiaryName!,
          cedulaJuridica: cedulaJuridica!,
        );
      case FundingMethod.crIbanUsd:
        return FundingDetails.crIbanUsd(
          iban: iban!,
          code: code!,
          beneficiaryName: beneficiaryName!,
          cedulaJuridica: cedulaJuridica!,
        );
      case FundingMethod.arsBankTransfer:
        return FundingDetails.arsBankTransfer(
          beneficiaryName: beneficiaryName!,
          cvu: cvu!,
        );
    }
  }
}
