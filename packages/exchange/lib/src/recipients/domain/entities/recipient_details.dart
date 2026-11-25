import 'package:exchange/src/recipients/domain/entities/recipient_type.dart';
import 'package:exchange/src/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:meta/meta.dart';

@immutable
sealed class RecipientDetails {
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
  final String? securityQuestion;
  final String? securityAnswer;

  const InteracEmailCadDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.email,
    required this.name,
    this.securityQuestion,
    this.securityAnswer,
  });

  factory InteracEmailCadDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String email,
    required String name,
    String? securityQuestion,
    String? securityAnswer,
  }) {
    if (email.trim().isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }
    final trimmedSecurityQuestion = securityQuestion?.trim();
    final trimmedSecurityAnswer = securityAnswer?.trim();
    final normalizedSecurityQuestion = trimmedSecurityQuestion?.isEmpty == false
        ? trimmedSecurityQuestion
        : null;
    final normalizedSecurityAnswer = trimmedSecurityAnswer?.isEmpty == false
        ? trimmedSecurityAnswer
        : null;
    final hasCompleteSecurityDetails =
        normalizedSecurityQuestion != null && normalizedSecurityAnswer != null;

    return InteracEmailCadDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      email: email.trim(),
      name: name.trim(),
      securityQuestion: hasCompleteSecurityDetails
          ? normalizedSecurityQuestion
          : null,
      securityAnswer: hasCompleteSecurityDetails
          ? normalizedSecurityAnswer
          : null,
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
  final SepaVirtualPayeeStatus virtualPayeeStatus;
  final bool isConfidential;

  const SepaEurDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.iban,
    required this.isCorporate,
    this.firstname,
    this.lastname,
    this.corporateName,
    this.virtualPayeeStatus = SepaVirtualPayeeStatus.absent,
    this.isConfidential = false,
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
    SepaVirtualPayeeStatus virtualPayeeStatus = SepaVirtualPayeeStatus.absent,
    bool isConfidential = false,
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
      virtualPayeeStatus: virtualPayeeStatus,
      isConfidential: isConfidential,
    );
  }

  bool get hasVirtualPayee => virtualPayeeStatus.exists;
  bool get isVirtualPayeeActive => virtualPayeeStatus.isActive;

  /// The API activates a virtual payee only for an individual recipient that
  /// the user owns.
  bool get canActivateVirtualPayee =>
      isOwner == true &&
      !isCorporate &&
      (firstname?.isNotEmpty ?? false) &&
      (lastname?.isNotEmpty ?? false);

  SepaEurDetails asConfidential() => SepaEurDetails._(
    label: label,
    isDefault: isDefault,
    isOwner: isOwner,
    iban: iban,
    isCorporate: isCorporate,
    firstname: firstname,
    lastname: lastname,
    corporateName: corporateName,
    virtualPayeeStatus: virtualPayeeStatus,
    isConfidential: true,
  );

  /// The same account, paid out through regular SEPA.
  SepaEurDetails asRegular() => SepaEurDetails._(
    label: label,
    isDefault: isDefault,
    isOwner: isOwner,
    iban: iban,
    isCorporate: isCorporate,
    firstname: firstname,
    lastname: lastname,
    corporateName: corporateName,
    virtualPayeeStatus: virtualPayeeStatus,
  );

  @override
  RecipientType get type => isConfidential
      ? RecipientType.confidentialSepaEur
      : RecipientType.sepaEur;
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
//
// The owner name comes from a Ridivi lookup on the server, which can fail or be
// empty on older records, so it is nullable by design (#2529). Display sites
// fall back to the label and then to the account identifier.
String? _nullIfBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

@immutable
class SinpeIbanUsdDetails extends RecipientDetails {
  final String iban;
  final String? ownerName;

  const SinpeIbanUsdDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.iban,
    this.ownerName,
  });

  factory SinpeIbanUsdDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String iban,
    String? ownerName,
  }) {
    if (iban.trim().isEmpty) {
      throw ArgumentError('IBAN cannot be empty');
    }

    return SinpeIbanUsdDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      iban: iban.trim(),
      ownerName: _nullIfBlank(ownerName),
    );
  }

  @override
  RecipientType get type => RecipientType.sinpeIbanUsd;
}

@immutable
class SinpeIbanCrcDetails extends RecipientDetails {
  final String iban;
  final String? ownerName;

  const SinpeIbanCrcDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.iban,
    this.ownerName,
  });

  factory SinpeIbanCrcDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String iban,
    String? ownerName,
  }) {
    if (iban.trim().isEmpty) {
      throw ArgumentError('IBAN cannot be empty');
    }

    return SinpeIbanCrcDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      iban: iban.trim(),
      ownerName: _nullIfBlank(ownerName),
    );
  }

  @override
  RecipientType get type => RecipientType.sinpeIbanCrc;
}

@immutable
class SinpeMovilCrcDetails extends RecipientDetails {
  final String phoneNumber;
  final String? ownerName;

  const SinpeMovilCrcDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.phoneNumber,
    this.ownerName,
  });

  factory SinpeMovilCrcDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String phoneNumber,
    String? ownerName,
  }) {
    if (phoneNumber.trim().isEmpty) {
      throw ArgumentError('Phone number cannot be empty');
    }

    return SinpeMovilCrcDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      phoneNumber: phoneNumber.trim(),
      ownerName: _nullIfBlank(ownerName),
    );
  }

  @override
  RecipientType get type => RecipientType.sinpeMovilCrc;
}

// ── Bank Account (Argentina)
@immutable
class BankAccountArgentinaDetails extends RecipientDetails {
  final String claveUniform;
  final String name;

  const BankAccountArgentinaDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.claveUniform,
    required this.name,
  });

  factory BankAccountArgentinaDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required String claveUniform,
    required String name,
  }) {
    if (claveUniform.trim().isEmpty) {
      throw ArgumentError('CBU/CVU cannot be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }

    return BankAccountArgentinaDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      claveUniform: claveUniform.trim(),
      name: name.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.bankAccountArgentina;
}

// ── PSE (Colombia)
@immutable
class PseColombiaDetails extends RecipientDetails {
  final ColombiaPayee payee;
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
    required this.payee,
    required this.accountType,
    required this.bankAccount,
    required this.bankCode,
    required this.bankName,
    required this.documentId,
    required this.documentType,
  });

  /// A new PSE recipient: the API requires the [holder]'s names and an
  /// [email], so a recipient without them can't be built.
  factory PseColombiaDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required ColombiaAccountHolder holder,
    required String email,
    required String accountType,
    required String bankAccount,
    required String bankCode,
    String bankName = '',
    required String documentId,
    required String documentType,
  }) => PseColombiaDetails._stored(
    label: label,
    isDefault: isDefault,
    isOwner: isOwner,
    payee: ColombiaContact.create(holder: holder, email: email),
    accountType: accountType,
    bankAccount: bankAccount,
    bankCode: bankCode,
    bankName: bankName,
    documentId: documentId,
    documentType: documentType,
  );

  /// A PSE recipient the server returned. [payee] may be a
  /// [ColombiaNameOnly] recipient saved before the API required the names
  /// and email.
  factory PseColombiaDetails.stored({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required ColombiaPayee payee,
    required String accountType,
    required String bankAccount,
    required String bankCode,
    String bankName = '',
    required String documentId,
    required String documentType,
  }) => PseColombiaDetails._stored(
    label: label,
    isDefault: isDefault,
    isOwner: isOwner,
    payee: payee,
    accountType: accountType,
    bankAccount: bankAccount,
    bankCode: bankCode,
    bankName: bankName,
    documentId: documentId,
    documentType: documentType,
  );

  static PseColombiaDetails _stored({
    required String? label,
    required bool isDefault,
    required bool? isOwner,
    required ColombiaPayee payee,
    required String accountType,
    required String bankAccount,
    required String bankCode,
    required String bankName,
    required String documentId,
    required String documentType,
  }) {
    if (accountType.trim().isEmpty) {
      throw ArgumentError('Account type cannot be empty');
    }
    if (bankAccount.trim().isEmpty) {
      throw ArgumentError('Bank account cannot be empty');
    }
    if (bankCode.trim().isEmpty) {
      throw ArgumentError('Bank code cannot be empty');
    }
    _requireColombiaDocument(documentId, documentType);

    return PseColombiaDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      payee: payee,
      accountType: accountType.trim(),
      bankAccount: bankAccount.trim(),
      bankCode: bankCode.trim(),
      bankName: bankName.trim(),
      documentId: documentId.trim(),
      documentType: documentType.trim(),
    );
  }

  /// The holder's name as shown in lists.
  String get name => payee.displayName;

  @override
  String? get firstName => payee.firstName;
  @override
  String? get lastName => payee.lastName;
  @override
  String? get email => payee.email;
  @override
  bool? get isCorporate => payee.isCorporate;
  @override
  String? get corporateName => payee.corporateName;

  @override
  RecipientType get type => RecipientType.pseColombia;
}

// ── Nequi (Colombia)
@immutable
class NequiColombiaDetails extends RecipientDetails {
  final ColombiaPayee payee;
  final String phoneNumber;
  final String documentId;
  final String documentType;

  const NequiColombiaDetails._({
    super.label,
    super.isDefault = false,
    super.isOwner,
    required this.payee,
    required this.phoneNumber,
    required this.documentId,
    required this.documentType,
  });

  /// A new Nequi recipient: the API requires the [holder]'s names and an
  /// [email], so a recipient without them can't be built.
  factory NequiColombiaDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required ColombiaAccountHolder holder,
    required String email,
    required String phoneNumber,
    required String documentId,
    required String documentType,
  }) => NequiColombiaDetails.stored(
    label: label,
    isDefault: isDefault,
    isOwner: isOwner,
    payee: ColombiaContact.create(holder: holder, email: email),
    phoneNumber: phoneNumber,
    documentId: documentId,
    documentType: documentType,
  );

  /// A Nequi recipient the server returned. [payee] may be a
  /// [ColombiaNameOnly] recipient saved before the API required the names
  /// and email.
  factory NequiColombiaDetails.stored({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required ColombiaPayee payee,
    required String phoneNumber,
    required String documentId,
    required String documentType,
  }) {
    if (phoneNumber.trim().isEmpty) {
      throw ArgumentError('Phone number cannot be empty');
    }
    _requireColombiaDocument(documentId, documentType);

    return NequiColombiaDetails._(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      payee: payee,
      phoneNumber: phoneNumber.trim(),
      documentId: documentId.trim(),
      documentType: documentType.trim(),
    );
  }

  /// The holder's name as shown in lists.
  String get name => payee.displayName;

  @override
  String? get firstName => payee.firstName;
  @override
  String? get lastName => payee.lastName;
  @override
  String? get email => payee.email;
  @override
  bool? get isCorporate => payee.isCorporate;
  @override
  String? get corporateName => payee.corporateName;

  @override
  RecipientType get type => RecipientType.nequiColombia;
}

void _requireColombiaDocument(String documentId, String documentType) {
  if (documentId.trim().isEmpty) {
    throw ArgumentError('Document ID cannot be empty');
  }
  if (documentType.trim().isEmpty) {
    throw ArgumentError('Document type cannot be empty');
  }
}

// ── Colombian account holder

/// Who holds a Colombian account: a person or a company.
@immutable
sealed class ColombiaAccountHolder {
  const ColombiaAccountHolder();

  String get displayName;
}

/// A person. The API requires both names.
final class ColombiaIndividual extends ColombiaAccountHolder {
  final String firstName;
  final String lastName;

  const ColombiaIndividual._(this.firstName, this.lastName);

  factory ColombiaIndividual.create({
    required String firstName,
    required String lastName,
  }) {
    if (firstName.trim().isEmpty) {
      throw ArgumentError('First name cannot be empty');
    }
    if (lastName.trim().isEmpty) {
      throw ArgumentError('Last name cannot be empty');
    }
    return ColombiaIndividual._(firstName.trim(), lastName.trim());
  }

  @override
  String get displayName => '$firstName $lastName';
}

/// A company, by its name.
final class ColombiaCorporate extends ColombiaAccountHolder {
  final String corporateName;

  const ColombiaCorporate._(this.corporateName);

  factory ColombiaCorporate.create({required String corporateName}) {
    if (corporateName.trim().isEmpty) {
      throw ArgumentError('Corporate name cannot be empty');
    }
    return ColombiaCorporate._(corporateName.trim());
  }

  @override
  String get displayName => corporateName;
}

/// The person or company a Colombian recipient pays.
///
/// Only a [ColombiaContact] can be sent to the API to create a recipient:
/// [ColombiaNameOnly] exists only for recipients the server returns that
/// were saved before it required the names and email.
@immutable
sealed class ColombiaPayee {
  const ColombiaPayee();

  String get displayName;
  String? get firstName => null;
  String? get lastName => null;
  String? get email => null;
  bool? get isCorporate => null;
  String? get corporateName => null;
}

/// A holder with the email the API requires for every Colombian recipient.
final class ColombiaContact extends ColombiaPayee {
  final ColombiaAccountHolder holder;
  @override
  final String email;

  const ColombiaContact._(this.holder, this.email);

  factory ColombiaContact.create({
    required ColombiaAccountHolder holder,
    required String email,
  }) {
    if (email.trim().isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }
    return ColombiaContact._(holder, email.trim());
  }

  @override
  String get displayName => holder.displayName;
  @override
  String? get firstName => switch (holder) {
    ColombiaIndividual(:final firstName) => firstName,
    ColombiaCorporate() => null,
  };
  @override
  String? get lastName => switch (holder) {
    ColombiaIndividual(:final lastName) => lastName,
    ColombiaCorporate() => null,
  };
  @override
  bool get isCorporate => holder is ColombiaCorporate;
  @override
  String? get corporateName => switch (holder) {
    ColombiaIndividual() => null,
    ColombiaCorporate(:final corporateName) => corporateName,
  };
}

/// A recipient the server returned without the last name or email it now
/// requires: saved before the API required them. It can be listed and
/// picked, never created.
final class ColombiaNameOnly extends ColombiaPayee {
  final String name;

  const ColombiaNameOnly._(this.name);

  factory ColombiaNameOnly.create({required String name}) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }
    return ColombiaNameOnly._(name.trim());
  }

  @override
  String get displayName => name;
}
