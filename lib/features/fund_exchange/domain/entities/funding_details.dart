import 'package:meta/meta.dart';

@immutable
sealed class FundingDetails {
  const FundingDetails();
}

class ETransferFundingDetails extends FundingDetails {
  final String secretQuestion;
  final String beneficiaryName;
  final String beneficiaryEmail;

  const ETransferFundingDetails({
    required this.secretQuestion,
    required this.beneficiaryName,
    required this.beneficiaryEmail,
  });
}

class CanadaPostFundingDetails extends FundingDetails {
  final String code;

  const CanadaPostFundingDetails({required this.code});
}

class BillPaymentFundingDetails extends FundingDetails {
  final String code;
  final String billerName;

  const BillPaymentFundingDetails({
    required this.code,
    required this.billerName,
  });
}

class InstantSepaFundingDetails extends FundingDetails {
  final String code;
  final String iban;
  final String bic;
  final String beneficiaryName;
  final String beneficiaryAddress;
  final String bankAccountCountry;

  const InstantSepaFundingDetails({
    required this.code,
    required this.iban,
    required this.bic,
    required this.beneficiaryName,
    required this.beneficiaryAddress,
    required this.bankAccountCountry,
  });
}

class RegularSepaFundingDetails extends FundingDetails {
  final String code;
  final String iban;
  final String bic;
  final String beneficiaryName;
  final String beneficiaryAddress;
  final String bankCountry;

  const RegularSepaFundingDetails({
    required this.code,
    required this.iban,
    required this.bic,
    required this.beneficiaryName,
    required this.beneficiaryAddress,
    required this.bankCountry,
  });
}

class WireFundingDetails extends FundingDetails {
  final String code;
  final String beneficiaryName;
  final String bankAccountDetails;
  final String iban;
  final String swift;
  final String institutionNumber;
  final String transitNumber;
  final String accountNumber;
  final String routingNumber;
  final String beneficiaryAddress;
  final String bankAddress;
  final String bankName;

  const WireFundingDetails({
    required this.code,
    required this.beneficiaryName,
    required this.bankAccountDetails,
    required this.iban,
    required this.swift,
    required this.institutionNumber,
    required this.transitNumber,
    required this.accountNumber,
    required this.routingNumber,
    required this.beneficiaryAddress,
    required this.bankAddress,
    required this.bankName,
  });
}

class SpeiFundingDetails extends FundingDetails {
  final String code;
  final String bankName;
  final String beneficiaryName;
  final String clabe;

  const SpeiFundingDetails({
    required this.code,
    required this.bankName,
    required this.beneficiaryName,
    required this.clabe,
  });
}

class SinpeFundingDetails extends FundingDetails {
  final String number;
  final String beneficiaryName;

  const SinpeFundingDetails({
    required this.number,
    required this.beneficiaryName,
  });
}

class CrIbanCrcFundingDetails extends FundingDetails {
  final String iban;
  final String code;
  final String beneficiaryName;
  final String cedulaJuridica;

  const CrIbanCrcFundingDetails({
    required this.iban,
    required this.code,
    required this.beneficiaryName,
    required this.cedulaJuridica,
  });
}

class CrIbanUsdFundingDetails extends FundingDetails {
  final String iban;
  final String code;
  final String beneficiaryName;
  final String cedulaJuridica;

  const CrIbanUsdFundingDetails({
    required this.iban,
    required this.code,
    required this.beneficiaryName,
    required this.cedulaJuridica,
  });
}

class ArsBankTransferFundingDetails extends FundingDetails {
  final String beneficiaryName;
  final String cvu;

  const ArsBankTransferFundingDetails({
    required this.beneficiaryName,
    required this.cvu,
  });
}

class CopBankTransferFundingDetails extends FundingDetails {
  final String paymentLink;

  const CopBankTransferFundingDetails({required this.paymentLink});
}
