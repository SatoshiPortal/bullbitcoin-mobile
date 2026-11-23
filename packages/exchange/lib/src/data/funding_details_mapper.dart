import 'package:bbx_api/bbx_api.dart' show PaymentProcessorDetails;

import '../domain/entities/funding_details.dart';
import '../domain/entities/funding_method.dart';

/// Maps the fields required by the selected payment method; an incomplete
/// answer cannot be used as funding instructions.
FundingDetails? fundingDetails(
  PaymentProcessorDetails details,
  FundingMethod method,
) => switch ((method, details)) {
  (
    EmailETransfer(),
    PaymentProcessorDetails(
      code: final code?,
      beneficiaryName: final name?,
      beneficiaryEmail: final email?,
    ),
  ) =>
    ETransferFundingDetails(
      secretQuestion: code,
      beneficiaryName: name,
      beneficiaryEmail: email,
    ),
  (
    BankTransferWire(),
    PaymentProcessorDetails(
      code: final code?,
      beneficiaryName: final name?,
      bankAccountDetails: final account?,
      iban: final iban?,
      swift: final swift?,
      institutionNumber: final institution?,
      transitNumber: final transit?,
      accountNumber: final number?,
      routingNumber: final routing?,
      beneficiaryAddress: final address?,
      bankAddress: final bankAddress?,
      bankName: final bankName?,
    ),
  ) =>
    WireFundingDetails(
      code: code,
      beneficiaryName: name,
      bankAccountDetails: account,
      iban: iban,
      swift: swift,
      institutionNumber: institution,
      transitNumber: transit,
      accountNumber: number,
      routingNumber: routing,
      beneficiaryAddress: address,
      bankAddress: bankAddress,
      bankName: bankName,
    ),
  (
    OnlineBillPayment(),
    PaymentProcessorDetails(code: final code?, billerName: final biller?),
  ) =>
    BillPaymentFundingDetails(code: code, billerName: biller),
  (CanadaPost(), PaymentProcessorDetails(code: final code?)) =>
    CanadaPostFundingDetails(code: code),
  (
    InstantSepa(),
    PaymentProcessorDetails(
      code: final code?,
      iban: final iban?,
      bic: final bic?,
      beneficiaryName: final name?,
      beneficiaryAddress: final address?,
      bankAccountCountry: final country?,
    ),
  ) =>
    InstantSepaFundingDetails(
      code: code,
      iban: iban,
      bic: bic,
      beneficiaryName: name,
      beneficiaryAddress: address,
      bankAccountCountry: country,
    ),
  (
    RegularSepa(),
    PaymentProcessorDetails(
      code: final code?,
      iban: final iban?,
      bic: final bic?,
      beneficiaryName: final name?,
      beneficiaryAddress: final address?,
      bankCountry: final country?,
    ),
  ) =>
    RegularSepaFundingDetails(
      code: code,
      iban: iban,
      bic: bic,
      beneficiaryName: name,
      beneficiaryAddress: address,
      bankCountry: country,
    ),
  (
    SpeiTransfer(),
    PaymentProcessorDetails(
      code: final code?,
      bankName: final bank?,
      beneficiaryName: final name?,
      clabe: final clabe?,
    ),
  ) =>
    SpeiFundingDetails(
      code: code,
      bankName: bank,
      beneficiaryName: name,
      clabe: clabe,
    ),
  (
    Sinpe(),
    PaymentProcessorDetails(
      numTelefono: final number?,
      beneficiaryName: final name?,
    ),
  ) =>
    SinpeFundingDetails(number: number, beneficiaryName: name),
  (
    CrIbanCrc(),
    PaymentProcessorDetails(
      iban: final iban?,
      code: final code?,
      beneficiaryName: final name?,
      cedulaJuridica: final cedula?,
    ),
  ) =>
    CrIbanCrcFundingDetails(
      iban: iban,
      code: code,
      beneficiaryName: name,
      cedulaJuridica: cedula,
    ),
  (
    CrIbanUsd(),
    PaymentProcessorDetails(
      iban: final iban?,
      code: final code?,
      beneficiaryName: final name?,
      cedulaJuridica: final cedula?,
    ),
  ) =>
    CrIbanUsdFundingDetails(
      iban: iban,
      code: code,
      beneficiaryName: name,
      cedulaJuridica: cedula,
    ),
  (
    ArsBankTransfer(),
    PaymentProcessorDetails(beneficiaryName: final name?, cvu: final cvu?),
  ) =>
    ArsBankTransferFundingDetails(beneficiaryName: name, cvu: cvu),
  _ => null,
};
