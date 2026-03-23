// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'get_funding_details_response_model.freezed.dart';
part 'get_funding_details_response_model.g.dart';

@freezed
sealed class GetFundingDetailsResponseModel
    with _$GetFundingDetailsResponseModel {
  const factory GetFundingDetailsResponseModel({
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
    String? numTelefono,
    String? paymentLink,
  }) = _GetFundingDetailsResponseModel;

  const GetFundingDetailsResponseModel._();

  factory GetFundingDetailsResponseModel.fromJson(
    Map<String, dynamic> json,
  ) => _$GetFundingDetailsResponseModelFromJson(json);

  FundingDetails toDomain({required FundingMethod method}) {
    return switch (method) {
      EmailETransfer() => ETransferFundingDetails(
        secretQuestion: code!,
        beneficiaryName: beneficiaryName!,
        beneficiaryEmail: beneficiaryEmail!,
      ),
      BankTransferWire() => WireFundingDetails(
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
      ),
      OnlineBillPayment() => BillPaymentFundingDetails(
        code: code!,
        billerName: billerName!,
      ),
      CanadaPost() => CanadaPostFundingDetails(code: code!),
      InstantSepa() => InstantSepaFundingDetails(
        code: code!,
        iban: iban!,
        bic: bic!,
        beneficiaryName: beneficiaryName!,
        beneficiaryAddress: beneficiaryAddress!,
        bankAccountCountry: bankAccountCountry!,
      ),
      RegularSepa() => RegularSepaFundingDetails(
        code: code!,
        iban: iban!,
        bic: bic!,
        beneficiaryName: beneficiaryName!,
        beneficiaryAddress: beneficiaryAddress!,
        bankCountry: bankCountry!,
      ),
      SpeiTransfer() => SpeiFundingDetails(
        code: code!,
        bankName: bankName!,
        beneficiaryName: beneficiaryName!,
        clabe: clabe!,
      ),
      Sinpe() => SinpeFundingDetails(
        number: numTelefono!,
        beneficiaryName: beneficiaryName!,
      ),
      CrIbanCrc() => CrIbanCrcFundingDetails(
        iban: iban!,
        code: code!,
        beneficiaryName: beneficiaryName!,
        cedulaJuridica: cedulaJuridica!,
      ),
      CrIbanUsd() => CrIbanUsdFundingDetails(
        iban: iban!,
        code: code!,
        beneficiaryName: beneficiaryName!,
        cedulaJuridica: cedulaJuridica!,
      ),
      ArsBankTransfer() => ArsBankTransferFundingDetails(
        beneficiaryName: beneficiaryName!,
        cvu: cvu!,
      ),
      CopBankTransfer() => CopBankTransferFundingDetails(
        paymentLink: paymentLink!,
      ),
    };
  }
}
