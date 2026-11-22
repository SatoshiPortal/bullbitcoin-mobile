import 'package:meta/meta.dart';

/// The funding instructions supported from `getUserPaymentProcessorCode`.
///
/// `ppExtraData` values take precedence over `element` values. Numeric wire
/// values are exposed as their decimal string, as the funding UI expects.
@immutable
class PaymentProcessorDetails {
  final bool isEmpty;
  final String? code;
  final String? userNbr;
  final String? beneficiaryName;
  final String? beneficiaryEmail;
  final String? bankAccountDetails;
  final String? iban;
  final String? swift;
  final String? institutionNumber;
  final String? transitNumber;
  final String? accountNumber;
  final String? routingNumber;
  final String? beneficiaryAddress;
  final String? bankAddress;
  final String? bankName;
  final String? billerName;
  final String? bic;
  final String? bankAccountCountry;
  final String? bankCountry;
  final String? clabe;
  final String? cedulaJuridica;
  final String? cvu;
  final String? numTelefono;

  const PaymentProcessorDetails({
    this.isEmpty = true,
    this.code,
    this.userNbr,
    this.beneficiaryName,
    this.beneficiaryEmail,
    this.bankAccountDetails,
    this.iban,
    this.swift,
    this.institutionNumber,
    this.transitNumber,
    this.accountNumber,
    this.routingNumber,
    this.beneficiaryAddress,
    this.bankAddress,
    this.bankName,
    this.billerName,
    this.bic,
    this.bankAccountCountry,
    this.bankCountry,
    this.clabe,
    this.cedulaJuridica,
    this.cvu,
    this.numTelefono,
  });
}
