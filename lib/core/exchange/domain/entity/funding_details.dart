import 'package:freezed_annotation/freezed_annotation.dart';

part 'funding_details.freezed.dart';

@freezed
sealed class FundingDetails with _$FundingDetails {
  const factory FundingDetails.eTransfer({
    required String secretQuestion,
    required String secretAnswer,
    required String beneficiaryName,
    required String beneficiaryEmail,
  }) = ETransferFundingDetails;
  const factory FundingDetails.canadaPost({required String code}) =
      CanadaPostFundingDetails;
  const factory FundingDetails.billPayment({
    required String code,
    required String billerName,
  }) = BillPaymentFundingDetails;
  const factory FundingDetails.instantSepa({
    required String code,
    required String iban,
    required String bic,
    required String beneficiaryName,
    required String beneficiaryAddress,
    required String bankAccountCountry,
  }) = InstantSepaFundingDetails;
  const factory FundingDetails.regularSepa({required String code}) =
      RegularSepaFundingDetails;
  const factory FundingDetails.wire({
    required String code,
    required String beneficiaryName,
    required String bankAccountDetails,
    required String iban,
    required String swift,
    required String institutionNumber,
    required String transitNumber,
    required String accountNumber,
    required String routingNumber,
    required String beneficiaryAddress,
    required String bankAddress,
    required String bankName,
  }) = WireFundingDetails;
  const factory FundingDetails.spei({
    required String code,
    required String bankName,
    required String beneficiaryName,
    required String clabe,
  }) = SpeiFundingDetails;
  const factory FundingDetails.crIbanCrc({required String code}) =
      CrIbanCrcFundingDetails;
  const factory FundingDetails.crIbanUsd({required String code}) =
      CrIbanUsdFundingDetails;
  const FundingDetails._();
}
