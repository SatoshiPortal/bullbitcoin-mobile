import 'package:meta/meta.dart';

/// A fiat recipient to create with `createRecipientFiat`, one subclass per
/// `recipientTypeFiat`.
///
@immutable
sealed class NewFiatRecipient {
  final String? label;
  final bool? isOwner;
  final bool? isDefault;
  final bool isArchived;

  const NewFiatRecipient({
    this.label,
    this.isOwner,
    this.isDefault,
    this.isArchived = false,
  });

  /// The wire discriminator, for example `INTERAC_EMAIL_CAD`.
  String get recipientTypeFiat;
}

/// `INTERAC_EMAIL_CAD`.
final class NewInteracEmailCadRecipient extends NewFiatRecipient {
  final String email;
  final String name;
  final String? securityQuestion;
  final String? securityAnswer;

  const NewInteracEmailCadRecipient({
    required this.email,
    required this.name,
    this.securityQuestion,
    this.securityAnswer,
    super.label,
    super.isOwner,
    super.isDefault,
  });

  @override
  String get recipientTypeFiat => 'INTERAC_EMAIL_CAD';
}

/// `BILL_PAYMENT_CAD`.
final class NewBillPaymentCadRecipient extends NewFiatRecipient {
  final String payeeName;
  final String payeeCode;
  final String payeeAccountNumber;

  const NewBillPaymentCadRecipient({
    required this.payeeName,
    required this.payeeCode,
    required this.payeeAccountNumber,
    super.label,
    super.isOwner,
    super.isDefault,
  });

  @override
  String get recipientTypeFiat => 'BILL_PAYMENT_CAD';
}

/// `BANK_TRANSFER_CAD`.
final class NewBankTransferCadRecipient extends NewFiatRecipient {
  final String name;
  final String institutionNumber;
  final String transitNumber;
  final String accountNumber;
  final String? defaultComment;

  const NewBankTransferCadRecipient({
    required this.name,
    required this.institutionNumber,
    required this.transitNumber,
    required this.accountNumber,
    this.defaultComment,
    super.label,
    super.isOwner,
    super.isDefault,
  });

  @override
  String get recipientTypeFiat => 'BANK_TRANSFER_CAD';
}

/// `SEPA_EUR`. Regular and Confidential SEPA recipients are created alike.
final class NewSepaEurRecipient extends NewFiatRecipient {
  final String iban;
  final bool? isCorporate;
  final String? firstname;
  final String? lastname;
  final String? corporateName;

  const NewSepaEurRecipient({
    required this.iban,
    this.isCorporate,
    this.firstname,
    this.lastname,
    this.corporateName,
    super.label,
    super.isOwner,
    super.isDefault,
  });

  @override
  String get recipientTypeFiat => 'SEPA_EUR';
}

/// `SPEI_CLABE_MXN`.
final class NewSpeiClabeMxnRecipient extends NewFiatRecipient {
  final String name;
  final String clabe;

  const NewSpeiClabeMxnRecipient({
    required this.name,
    required this.clabe,
    super.label,
    super.isOwner,
    super.isDefault,
  });

  @override
  String get recipientTypeFiat => 'SPEI_CLABE_MXN';
}

/// `SPEI_SMS_MXN`.
final class NewSpeiSmsMxnRecipient extends NewFiatRecipient {
  final String name;
  final String institutionCode;
  final String phone;

  const NewSpeiSmsMxnRecipient({
    required this.name,
    required this.institutionCode,
    required this.phone,
    super.label,
    super.isOwner,
    super.isDefault,
  });

  @override
  String get recipientTypeFiat => 'SPEI_SMS_MXN';
}

/// `SPEI_CARD_MXN`.
final class NewSpeiCardMxnRecipient extends NewFiatRecipient {
  final String name;
  final String institutionCode;
  final String debitcard;

  const NewSpeiCardMxnRecipient({
    required this.name,
    required this.institutionCode,
    required this.debitcard,
    super.label,
    super.isOwner,
    super.isDefault,
  });

  @override
  String get recipientTypeFiat => 'SPEI_CARD_MXN';
}

/// `SINPE_IBAN_USD`.
final class NewSinpeIbanUsdRecipient extends NewFiatRecipient {
  final String iban;
  final String? ownerName;

  const NewSinpeIbanUsdRecipient({
    required this.iban,
    this.ownerName,
    super.label,
    super.isOwner,
    super.isDefault,
  });

  @override
  String get recipientTypeFiat => 'SINPE_IBAN_USD';
}

/// `SINPE_IBAN_CRC`.
final class NewSinpeIbanCrcRecipient extends NewFiatRecipient {
  final String iban;
  final String? ownerName;

  const NewSinpeIbanCrcRecipient({
    required this.iban,
    this.ownerName,
    super.label,
    super.isOwner,
    super.isDefault,
  });

  @override
  String get recipientTypeFiat => 'SINPE_IBAN_CRC';
}

/// `SINPE_MOVIL_CRC`.
final class NewSinpeMovilCrcRecipient extends NewFiatRecipient {
  final String phoneNumber;
  final String? ownerName;

  const NewSinpeMovilCrcRecipient({
    required this.phoneNumber,
    this.ownerName,
    super.label,
    super.isOwner,
    super.isDefault,
  });

  @override
  String get recipientTypeFiat => 'SINPE_MOVIL_CRC';
}

/// `BANK_TRANSFER_ARS`: an Argentine CBU or CVU.
final class NewBankTransferArsRecipient extends NewFiatRecipient {
  final String name;
  final String claveUniform;

  const NewBankTransferArsRecipient({
    required this.name,
    required this.claveUniform,
    super.label,
    super.isOwner,
    super.isDefault,
  });

  @override
  String get recipientTypeFiat => 'BANK_TRANSFER_ARS';
}

/// `PSE_COLOMBIA_COP`.
final class NewPseColombiaCopRecipient extends NewFiatRecipient {
  final String name;
  final String bankCode;
  final String accountType;
  final String bankAccount;
  final String bankName;
  final String documentId;
  final String documentType;

  const NewPseColombiaCopRecipient({
    required this.name,
    required this.bankCode,
    required this.accountType,
    required this.bankAccount,
    required this.bankName,
    required this.documentId,
    required this.documentType,
    super.label,
    super.isOwner,
    super.isDefault,
  });

  @override
  String get recipientTypeFiat => 'PSE_COLOMBIA_COP';
}

/// `NEQUI_COLOMBIA_COP`. The Nequi phone number is sent as `bankAccount`.
final class NewNequiColombiaCopRecipient extends NewFiatRecipient {
  final String name;
  final String bankAccount;
  final String documentId;
  final String documentType;

  const NewNequiColombiaCopRecipient({
    required this.name,
    required this.bankAccount,
    required this.documentId,
    required this.documentType,
    super.label,
    super.isOwner,
    super.isDefault,
  });

  @override
  String get recipientTypeFiat => 'NEQUI_COLOMBIA_COP';
}
