import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:meta/meta.dart';

@immutable
abstract class RecipientDetails {
  final String? label;
  final bool isDefault;
  final bool? isOwner;

  const RecipientDetails({this.label, this.isDefault = false, this.isOwner});

  RecipientType get type;
  String? get firstName => null;
  String? get lastName => null;
  String? get email => null;
  bool? get isCorporate => null;
  String? get corporateName => null;
}

// ── Interac Email (CAD)
@immutable
class InteracEmailCadDetails extends RecipientDetails {
  @override
  final String email;
  final String name;
  final String securityQuestion;
  final String securityAnswer;

  const InteracEmailCadDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.email,
    required this.name,
    required this.securityQuestion,
    required this.securityAnswer,
  });

  factory InteracEmailCadDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String email,
    required String name,
    String securityQuestion = 'What is your favorite color?',
    String securityAnswer = 'Orange',
  }) {
    if (email.trim().isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }
    if (securityQuestion.trim().isEmpty) {
      throw ArgumentError('Security question cannot be empty');
    }
    if (securityAnswer.trim().isEmpty) {
      throw ArgumentError('Security answer cannot be empty');
    }

    return InteracEmailCadDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      email: email.trim(),
      name: name.trim(),
      securityQuestion: securityQuestion.trim(),
      securityAnswer: securityAnswer.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.interacEmailCad;
}

// ── Bill Payment (CAD)
@immutable
class BillPaymentCadDetails extends RecipientDetails {
  final String payeeName;
  final String payeeCode;
  final String payeeAccountNumber;

  const BillPaymentCadDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.payeeName,
    required this.payeeCode,
    required this.payeeAccountNumber,
  });

  factory BillPaymentCadDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String payeeName,
    required String payeeCode,
    required String payeeAccountNumber,
  }) {
    if (payeeName.trim().isEmpty) {
      throw ArgumentError('Payee name cannot be empty');
    }
    if (payeeCode.trim().isEmpty) {
      throw ArgumentError('Payee code cannot be empty');
    }
    if (payeeAccountNumber.trim().isEmpty) {
      throw ArgumentError('Payee account number cannot be empty');
    }

    return BillPaymentCadDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      payeeName: payeeName.trim(),
      payeeCode: payeeCode.trim(),
      payeeAccountNumber: payeeAccountNumber.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.billPaymentCad;
}

// ── Bank Transfer (CAD)
@immutable
class BankTransferCadDetails extends RecipientDetails {
  final String institutionNumber;
  final String transitNumber;
  final String accountNumber;
  final String name;
  final String? defaultComment;

  const BankTransferCadDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.institutionNumber,
    required this.transitNumber,
    required this.accountNumber,
    required this.name,
    this.defaultComment,
  });

  factory BankTransferCadDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String institutionNumber,
    required String transitNumber,
    required String accountNumber,
    required String name,
    String? defaultComment,
  }) {
    if (institutionNumber.trim().isEmpty) {
      throw ArgumentError('Institution number cannot be empty');
    }
    if (transitNumber.trim().isEmpty) {
      throw ArgumentError('Transit number cannot be empty');
    }
    if (accountNumber.trim().isEmpty) {
      throw ArgumentError('Account number cannot be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }

    return BankTransferCadDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      institutionNumber: institutionNumber.trim(),
      transitNumber: transitNumber.trim(),
      accountNumber: accountNumber.trim(),
      name: name.trim(),
      defaultComment: defaultComment?.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.bankTransferCad;
}

// ── SEPA (EUR)
@immutable
class SepaEurDetails extends RecipientDetails {
  final String iban;
  @override
  final bool isCorporate;
  final String? firstname;
  final String? lastname;
  @override
  final String? corporateName;

  const SepaEurDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.iban,
    required this.isCorporate,
    this.firstname,
    this.lastname,
    this.corporateName,
  });

  factory SepaEurDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String iban,
    required bool isCorporate,
    String? firstname,
    String? lastname,
    String? corporateName,
  }) {
    if (iban.trim().isEmpty) {
      throw ArgumentError('IBAN cannot be empty');
    }
    if (isCorporate) {
      if (corporateName == null || corporateName.trim().isEmpty) {
        throw ArgumentError(
          'Corporate name is required for corporate accounts',
        );
      }
    } else {
      if ((firstname == null || firstname.trim().isEmpty) ||
          (lastname == null || lastname.trim().isEmpty)) {
        throw ArgumentError(
          'First name and last name are required for non-corporate accounts',
        );
      }
    }

    return SepaEurDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      iban: iban.trim(),
      isCorporate: isCorporate,
      firstname: firstname?.trim(),
      lastname: lastname?.trim(),
      corporateName: corporateName?.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.sepaEur;
}

// ── SPEI (MXN)
@immutable
class SpeiClabeMxnDetails extends RecipientDetails {
  final String clabe;
  final String name;

  const SpeiClabeMxnDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.clabe,
    required this.name,
  });

  factory SpeiClabeMxnDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String clabe,
    required String name,
  }) {
    if (clabe.trim().isEmpty) {
      throw ArgumentError('CLABE cannot be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }

    return SpeiClabeMxnDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      clabe: clabe.trim(),
      name: name.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.speiClabeMxn;
}

@immutable
class SpeiSmsMxnDetails extends RecipientDetails {
  final String institutionCode;
  final String phone;
  final String name;

  const SpeiSmsMxnDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.institutionCode,
    required this.phone,
    required this.name,
  });

  factory SpeiSmsMxnDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String institutionCode,
    required String phone,
    required String name,
  }) {
    if (institutionCode.trim().isEmpty) {
      throw ArgumentError('Institution code cannot be empty');
    }
    if (phone.trim().isEmpty) {
      throw ArgumentError('Phone cannot be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }

    return SpeiSmsMxnDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      institutionCode: institutionCode.trim(),
      phone: phone.trim(),
      name: name.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.speiSmsMxn;
}

@immutable
class SpeiCardMxnDetails extends RecipientDetails {
  final String institutionCode;
  final String debitcard;
  final String name;

  const SpeiCardMxnDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.institutionCode,
    required this.debitcard,
    required this.name,
  });

  factory SpeiCardMxnDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String institutionCode,
    required String debitcard,
    required String name,
  }) {
    if (institutionCode.trim().isEmpty) {
      throw ArgumentError('Institution code cannot be empty');
    }
    if (debitcard.trim().isEmpty) {
      throw ArgumentError('Debit card cannot be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }

    return SpeiCardMxnDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      institutionCode: institutionCode.trim(),
      debitcard: debitcard.trim(),
      name: name.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.speiCardMxn;
}

// ── SINPE (CRC/USD)
@immutable
class SinpeIbanUsdDetails extends RecipientDetails {
  final String iban;
  final String ownerName;

  const SinpeIbanUsdDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.iban,
    required this.ownerName,
  });

  factory SinpeIbanUsdDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String iban,
    required String ownerName,
  }) {
    if (iban.trim().isEmpty) {
      throw ArgumentError('IBAN cannot be empty');
    }
    if (ownerName.trim().isEmpty) {
      throw ArgumentError('Owner name cannot be empty');
    }

    return SinpeIbanUsdDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      iban: iban.trim(),
      ownerName: ownerName.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.sinpeIbanUsd;
}

@immutable
class SinpeIbanCrcDetails extends RecipientDetails {
  final String iban;
  final String ownerName;

  const SinpeIbanCrcDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.iban,
    required this.ownerName,
  });

  factory SinpeIbanCrcDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String iban,
    required String ownerName,
  }) {
    if (iban.trim().isEmpty) {
      throw ArgumentError('IBAN cannot be empty');
    }
    if (ownerName.trim().isEmpty) {
      throw ArgumentError('Owner name cannot be empty');
    }

    return SinpeIbanCrcDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      iban: iban.trim(),
      ownerName: ownerName.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.sinpeIbanCrc;
}

@immutable
class SinpeMovilCrcDetails extends RecipientDetails {
  final String phoneNumber;
  final String ownerName;

  const SinpeMovilCrcDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.phoneNumber,
    required this.ownerName,
  });

  factory SinpeMovilCrcDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String phoneNumber,
    required String ownerName,
  }) {
    if (phoneNumber.trim().isEmpty) {
      throw ArgumentError('Phone number cannot be empty');
    }
    if (ownerName.trim().isEmpty) {
      throw ArgumentError('Owner name cannot be empty');
    }

    return SinpeMovilCrcDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      phoneNumber: phoneNumber.trim(),
      ownerName: ownerName.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.sinpeMovilCrc;
}

// ── CBU/CVU (Argentina)
@immutable
class CbuCvuArgentinaDetails extends RecipientDetails {
  final String cbuCvu;
  final String name;

  const CbuCvuArgentinaDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.cbuCvu,
    required this.name,
  });

  factory CbuCvuArgentinaDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String cbuCvu,
    required String name,
  }) {
    if (cbuCvu.trim().isEmpty) {
      throw ArgumentError('CBU/CVU cannot be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }

    return CbuCvuArgentinaDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      cbuCvu: cbuCvu.trim(),
      name: name.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.cbuCvuArgentina;
}

// ── PSE (Colombia)
@immutable
class PseColombiaDetails extends RecipientDetails {
  @override
  final bool isCorporate;
  final String? name;
  final String? lastname;
  @override
  final String? corporateName;
  @override
  final String email;
  final String accountType;
  final String bankAccount;
  final String bankCode;
  final String bankName;
  final String documentId;
  final String documentType;

  const PseColombiaDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.isCorporate,
    this.name,
    this.lastname,
    this.corporateName,
    required this.email,
    required this.accountType,
    required this.bankAccount,
    required this.bankCode,
    required this.bankName,
    required this.documentId,
    required this.documentType,
  });

  factory PseColombiaDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required bool isCorporate,
    String? name,
    String? lastname,
    String? corporateName,
    required String email,
    required String accountType,
    required String bankAccount,
    required String bankCode,
    required String bankName,
    required String documentId,
    required String documentType,
  }) {
    if (isCorporate) {
      if (corporateName == null || corporateName.trim().isEmpty) {
        throw ArgumentError(
          'Corporate name is required for corporate accounts',
        );
      }
    } else {
      if ((name == null || name.trim().isEmpty)) {
        throw ArgumentError('Name is required for individual accounts');
      }
    }
    if (accountType.trim().isEmpty) {
      throw ArgumentError('Account type cannot be empty');
    }
    if (bankAccount.trim().isEmpty) {
      throw ArgumentError('Bank account cannot be empty');
    }
    if (bankCode.trim().isEmpty) {
      throw ArgumentError('Bank code cannot be empty');
    }
    if (documentId.trim().isEmpty) {
      throw ArgumentError('Document ID cannot be empty');
    }
    if (documentType.trim().isEmpty) {
      throw ArgumentError('Document type cannot be empty');
    }

    return PseColombiaDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      isCorporate: isCorporate,
      name: name?.trim(),
      lastname: lastname?.trim(),
      corporateName: corporateName?.trim(),
      email: email.trim(),
      accountType: accountType.trim(),
      bankAccount: bankAccount.trim(),
      bankCode: bankCode.trim(),
      bankName: bankName.trim(),
      documentId: documentId.trim(),
      documentType: documentType.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.pseColombia;
}

// ── Nequi (Colombia)
@immutable
class NequiColombiaDetails extends RecipientDetails {
  final String phoneNumber;
  final String documentId;
  final String documentType;
  @override
  final bool isCorporate;
  final String? name;
  final String? lastname;
  @override
  final String? corporateName;
  @override
  final String email;

  const NequiColombiaDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.phoneNumber,
    required this.documentId,
    required this.documentType,
    required this.isCorporate,
    this.name,
    this.lastname,
    this.corporateName,
    required this.email,
  });

  factory NequiColombiaDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required bool isCorporate,
    String? name,
    String? lastname,
    String? corporateName,
    required String email,
    required String phoneNumber,
    required String documentId,
    required String documentType,
  }) {
    if (isCorporate) {
      if (corporateName == null || corporateName.trim().isEmpty) {
        throw ArgumentError(
          'Corporate name is required for corporate accounts',
        );
      }
    } else {
      if ((name == null || name.trim().isEmpty)) {
        throw ArgumentError('Name is required for individual accounts');
      }
    }
    if (phoneNumber.trim().isEmpty) {
      throw ArgumentError('Phone number cannot be empty');
    }
    if (documentId.trim().isEmpty) {
      throw ArgumentError('Document ID cannot be empty');
    }
    if (documentType.trim().isEmpty) {
      throw ArgumentError('Document type cannot be empty');
    }

    return NequiColombiaDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      isCorporate: isCorporate,
      name: name?.trim(),
      lastname: lastname?.trim(),
      corporateName: corporateName?.trim(),
      email: email.trim(),
      phoneNumber: phoneNumber.trim(),
      documentId: documentId.trim(),
      documentType: documentType.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.nequiColombia;
}
