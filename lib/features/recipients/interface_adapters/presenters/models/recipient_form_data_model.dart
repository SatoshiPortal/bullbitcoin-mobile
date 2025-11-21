import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';

/// Base class for form data from UI layer
/// Each form submits its specific subtype
/// Bloc receives base type and transforms to RecipientDetailsDto
sealed class RecipientFormDataModel {
  final String? label;
  final RecipientType type;

  const RecipientFormDataModel({required this.type, this.label});

  /// Transform form data to application DTO
  RecipientDetailsDto toDto();
}

// ══════════════════════════════════════════════════════════════════════════════
// CANADA
// ══════════════════════════════════════════════════════════════════════════════

class InteracEmailCadFormDataModel extends RecipientFormDataModel {
  final String email;
  final String name;
  final String securityQuestion;
  final String securityAnswer;
  final bool isOwner;

  const InteracEmailCadFormDataModel({
    required this.email,
    required this.name,
    required this.securityQuestion,
    required this.securityAnswer,
    required this.isOwner,
    super.label,
  }) : super(type: RecipientType.interacEmailCad);

  @override
  RecipientDetailsDto toDto() {
    return RecipientDetailsDto(
      recipientType: type,
      isOwner: isOwner,
      label: label,
      email: email,
      name: name,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    );
  }
}

class BillPaymentCadFormDataModel extends RecipientFormDataModel {
  final String payeeName;
  final String payeeCode;
  final String payeeAccountNumber;

  const BillPaymentCadFormDataModel({
    required this.payeeName,
    required this.payeeCode,
    required this.payeeAccountNumber,
    super.label,
  }) : super(type: RecipientType.billPaymentCad);

  @override
  RecipientDetailsDto toDto() {
    return RecipientDetailsDto(
      recipientType: type,
      label: label,
      payeeName: payeeName,
      payeeCode: payeeCode,
      payeeAccountNumber: payeeAccountNumber,
    );
  }
}

class BankTransferCadFormDataModel extends RecipientFormDataModel {
  final String institutionNumber;
  final String transitNumber;
  final String accountNumber;
  final String name;
  final String? defaultComment;
  final bool isOwner;

  const BankTransferCadFormDataModel({
    required this.institutionNumber,
    required this.transitNumber,
    required this.accountNumber,
    required this.name,
    required this.isOwner,
    this.defaultComment,
    super.label,
  }) : super(type: RecipientType.bankTransferCad);

  @override
  RecipientDetailsDto toDto() {
    return RecipientDetailsDto(
      recipientType: type,
      isOwner: isOwner,
      label: label,
      institutionNumber: institutionNumber,
      transitNumber: transitNumber,
      accountNumber: accountNumber,
      name: name,
      defaultComment: defaultComment,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EUROPE
// ══════════════════════════════════════════════════════════════════════════════

class SepaEurFormDataModel extends RecipientFormDataModel {
  final String iban;
  final bool isCorporate;
  final String? firstname;
  final String? lastname;
  final String? corporateName;
  final bool isOwner;

  const SepaEurFormDataModel({
    required this.iban,
    required this.isCorporate,
    required this.isOwner,
    this.firstname,
    this.lastname,
    this.corporateName,
    super.label,
  }) : super(type: RecipientType.sepaEur);

  @override
  RecipientDetailsDto toDto() {
    return RecipientDetailsDto(
      recipientType: type,
      isOwner: isOwner,
      label: label,
      iban: iban,
      isCorporate: isCorporate,
      firstname: firstname,
      lastname: lastname,
      corporateName: corporateName,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MEXICO
// ══════════════════════════════════════════════════════════════════════════════

class SpeiClabeMxnFormDataModel extends RecipientFormDataModel {
  final String clabe;
  final String name;

  const SpeiClabeMxnFormDataModel({
    required this.clabe,
    required this.name,
    super.label,
  }) : super(type: RecipientType.speiClabeMxn);

  @override
  RecipientDetailsDto toDto() {
    return RecipientDetailsDto(
      recipientType: type,
      label: label,
      clabe: clabe,
      name: name,
    );
  }
}

class SpeiSmsMxnFormDataModel extends RecipientFormDataModel {
  final String institutionCode;
  final String phone;
  final String name;

  const SpeiSmsMxnFormDataModel({
    required this.institutionCode,
    required this.phone,
    required this.name,
    super.label,
  }) : super(type: RecipientType.speiSmsMxn);

  @override
  RecipientDetailsDto toDto() {
    return RecipientDetailsDto(
      recipientType: type,
      label: label,
      institutionCode: institutionCode,
      phone: phone,
      name: name,
    );
  }
}

class SpeiCardMxnFormDataModel extends RecipientFormDataModel {
  final String institutionCode;
  final String debitcard;
  final String name;

  const SpeiCardMxnFormDataModel({
    required this.institutionCode,
    required this.debitcard,
    required this.name,
    super.label,
  }) : super(type: RecipientType.speiCardMxn);

  @override
  RecipientDetailsDto toDto() {
    return RecipientDetailsDto(
      recipientType: type,
      label: label,
      institutionCode: institutionCode,
      debitcard: debitcard,
      name: name,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COSTA RICA
// ══════════════════════════════════════════════════════════════════════════════

class SinpeIbanUsdFormDataModel extends RecipientFormDataModel {
  final String iban;
  final String ownerName;

  const SinpeIbanUsdFormDataModel({
    required this.iban,
    required this.ownerName,
    super.label,
  }) : super(type: RecipientType.sinpeIbanUsd);

  @override
  RecipientDetailsDto toDto() {
    return RecipientDetailsDto(
      recipientType: type,
      label: label,
      iban: iban,
      ownerName: ownerName,
    );
  }
}

class SinpeIbanCrcFormDataModel extends RecipientFormDataModel {
  final String iban;
  final String ownerName;

  const SinpeIbanCrcFormDataModel({
    required this.iban,
    required this.ownerName,
    super.label,
  }) : super(type: RecipientType.sinpeIbanCrc);

  @override
  RecipientDetailsDto toDto() {
    return RecipientDetailsDto(
      recipientType: type,
      label: label,
      iban: iban,
      ownerName: ownerName,
    );
  }
}

class SinpeMovilCrcFormDataModel extends RecipientFormDataModel {
  final String phoneNumber;
  final String ownerName;

  const SinpeMovilCrcFormDataModel({
    required this.phoneNumber,
    required this.ownerName,
    super.label,
  }) : super(type: RecipientType.sinpeMovilCrc);

  @override
  RecipientDetailsDto toDto() {
    return RecipientDetailsDto(
      recipientType: type,
      label: label,
      phoneNumber: phoneNumber,
      ownerName: ownerName,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ARGENTINA
// ══════════════════════════════════════════════════════════════════════════════

class CbuCvuArgentinaFormDataModel extends RecipientFormDataModel {
  final String cbuCvu;
  final String name;

  const CbuCvuArgentinaFormDataModel({
    required this.cbuCvu,
    required this.name,
    super.label,
  }) : super(type: RecipientType.cbuCvuArgentina);

  @override
  RecipientDetailsDto toDto() {
    return RecipientDetailsDto(
      recipientType: type,
      label: label,
      cbuCvu: cbuCvu,
      name: name,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COLOMBIA
// ══════════════════════════════════════════════════════════════════════════════
class PseColombiaFormDataModel extends RecipientFormDataModel {
  final String bankCode;
  final String accountType;
  final String bankAccount;
  final String documentType;
  final String documentId;
  final String name;

  const PseColombiaFormDataModel({
    required this.bankCode,
    required this.accountType,
    required this.bankAccount,
    required this.documentType,
    required this.documentId,
    required this.name,
    super.label,
  }) : super(type: RecipientType.pseColombia);

  @override
  RecipientDetailsDto toDto() {
    return RecipientDetailsDto(
      recipientType: type,
      bankCode: bankCode,
      accountType: accountType,
      bankAccount: bankAccount,
      documentType: documentType,
      documentId: documentId,
      name: name,
      label: label,
    );
  }
}

class NequiColombiaFormDataModel extends RecipientFormDataModel {
  final String phoneNumber;
  final String documentType;
  final String documentId;
  final String name;

  const NequiColombiaFormDataModel({
    required this.phoneNumber,
    required this.documentType,
    required this.documentId,
    required this.name,
    super.label,
  }) : super(type: RecipientType.nequiColombia);

  @override
  RecipientDetailsDto toDto() {
    return RecipientDetailsDto(
      recipientType: type,
      phoneNumber: phoneNumber,
      documentType: documentType,
      documentId: documentId,
      name: name,
      label: label,
    );
  }
}
