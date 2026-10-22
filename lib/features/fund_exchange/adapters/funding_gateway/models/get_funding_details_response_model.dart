// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/funding_datasource_exception.dart';
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

  factory GetFundingDetailsResponseModel.fromJson(Map<String, dynamic> json) =>
      _$GetFundingDetailsResponseModelFromJson(_validatedJson(json));

  static Map<String, dynamic> _validatedJson(Map<String, dynamic> json) {
    // Validate known wire fields before generated casts; ignore extra metadata.
    for (final name in const [
      'code',
      'userNbr',
      'BENEFICIARY NAME',
      'BENEFICIARY EMAIL',
      'BANK ACCOUNT DETAILS',
      'IBAN',
      'SWIFT',
      'INSTITUTION NUMBER',
      'TRANSIT NUMBER',
      'ACCOUNT NUMBER',
      'ROUTING NUMBER',
      'BENEFICIARY ADDRESS',
      'BANK ADDRESS',
      'BANK NAME',
      'BILLER NAME',
      'BIC',
      'BANK ACCOUNT COUNTRY',
      'BANK COUNTRY',
      'CLABE',
      'CÉDULA JURÍDICA',
      'CVU',
      'numTelefono',
      'paymentLink',
    ]) {
      final value = json[name];
      if (value != null && value is! String) {
        throw const FundingResponseException('Invalid funding detail type');
      }
    }
    return json;
  }

  static String _required(String? value) {
    if (value == null) {
      throw const FundingResponseException('Missing required funding detail');
    }
    return value;
  }

  FundingDetails toDomain({required FundingMethod method}) {
    return switch (method) {
      EmailETransfer() => ETransferFundingDetails(
        secretQuestion: _required(code),
        beneficiaryName: _required(beneficiaryName),
        beneficiaryEmail: _required(beneficiaryEmail),
      ),
      BankTransferWire() => WireFundingDetails(
        code: _required(code),
        beneficiaryName: _required(beneficiaryName),
        bankAccountDetails: _required(bankAccountDetails),
        iban: _required(iban),
        swift: _required(swift),
        institutionNumber: _required(institutionNumber),
        transitNumber: _required(transitNumber),
        accountNumber: _required(accountNumber),
        routingNumber: _required(routingNumber),
        beneficiaryAddress: _required(beneficiaryAddress),
        bankAddress: _required(bankAddress),
        bankName: _required(bankName),
      ),
      OnlineBillPayment() => BillPaymentFundingDetails(
        code: _required(code),
        billerName: _required(billerName),
      ),
      CanadaPost() => CanadaPostFundingDetails(code: _required(code)),
      InstantSepa() => InstantSepaFundingDetails(
        code: _required(code),
        iban: _required(iban),
        bic: _required(bic),
        beneficiaryName: _required(beneficiaryName),
        beneficiaryAddress: _required(beneficiaryAddress),
        bankAccountCountry: _required(bankAccountCountry),
      ),
      RegularSepa() => RegularSepaFundingDetails(
        code: _required(code),
        iban: _required(iban),
        bic: _required(bic),
        beneficiaryName: _required(beneficiaryName),
        beneficiaryAddress: _required(beneficiaryAddress),
        bankCountry: _required(bankCountry),
      ),
      SpeiTransfer() => SpeiFundingDetails(
        code: _required(code),
        bankName: _required(bankName),
        beneficiaryName: _required(beneficiaryName),
        clabe: _required(clabe),
      ),
      Sinpe() => SinpeFundingDetails(
        number: _required(numTelefono),
        beneficiaryName: _required(beneficiaryName),
      ),
      CrIbanCrc() => CrIbanCrcFundingDetails(
        iban: _required(iban),
        code: _required(code),
        beneficiaryName: _required(beneficiaryName),
        cedulaJuridica: _required(cedulaJuridica),
      ),
      CrIbanUsd() => CrIbanUsdFundingDetails(
        iban: _required(iban),
        code: _required(code),
        beneficiaryName: _required(beneficiaryName),
        cedulaJuridica: _required(cedulaJuridica),
      ),
      ArsBankTransfer() => ArsBankTransferFundingDetails(
        beneficiaryName: _required(beneficiaryName),
        cvu: _required(cvu),
      ),
      CopBankTransfer() => CopBankTransferFundingDetails(
        paymentLink: _required(paymentLink),
      ),
    };
  }
}
