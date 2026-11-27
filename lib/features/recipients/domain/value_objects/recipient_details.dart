import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_field_checks.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_virtual_payee_status.dart';
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

    return SepaEurDetails.saved(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      iban: iban,
      isCorporate: isCorporate,
      firstname: firstname,
      lastname: lastname,
      corporateName: corporateName,
      virtualPayeeStatus: virtualPayeeStatus,
      isConfidential: isConfidential,
    );
  }

  /// A recipient that the API already has. Names are not checked: the API
  /// can return a recipient without a last name, for example when the name
  /// of its virtual payee is a single word.
  factory SepaEurDetails.saved({
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

  @override
  RecipientType get type => isConfidential
      ? RecipientType.confidentialSepaEur
      : RecipientType.sepaEur;
}

// ── SPEI (MXN)
//
// `create` is for a new recipient and also checks the format of the CLABE,
// phone or card number, so a mistyped one is never sent. `saved` is for a
// recipient the API already holds, listed as it is.
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
    final problem = speiClabeProblem(clabe);
    if (problem != null) {
      throw ArgumentError('Invalid CLABE: ${problem.name}');
    }
    return SpeiClabeMxnDetails.saved(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      clabe: clabe,
      name: name,
    );
  }

  factory SpeiClabeMxnDetails.saved({
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
    final problem = speiPhoneProblem(phone);
    if (problem != null) {
      throw ArgumentError('Invalid SPEI phone: ${problem.name}');
    }
    return SpeiSmsMxnDetails.saved(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      institutionCode: institutionCode,
      phone: phone,
      name: name,
    );
  }

  factory SpeiSmsMxnDetails.saved({
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
    final problem = speiDebitCardProblem(debitcard);
    if (problem != null) {
      throw ArgumentError('Invalid SPEI debit card: ${problem.name}');
    }
    return SpeiCardMxnDetails.saved(
      label: label,
      isDefault: isDefault,
      isOwner: isOwner,
      institutionCode: institutionCode,
      debitcard: debitcard,
      name: name,
    );
  }

  factory SpeiCardMxnDetails.saved({
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

// ── Colombia (PSE and Nequi)
//
// The API requires an email for every Colombian recipient, and either a
// person's first and last name or, with `isCorporate`, a company name. A new
// recipient takes a [ColombiaContact], which can only be built with both.

/// Who holds a Colombian account: a person or a company.
@immutable
sealed class CopHolder {
  const CopHolder();

  String get displayName;
}

/// A person, sent as `isCorporate: false`, `name` and `lastname`.
final class CopIndividual extends CopHolder {
  final String name;
  final String lastname;

  const CopIndividual._({required this.name, required this.lastname});

  factory CopIndividual({required String name, required String lastname}) {
    if (name.trim().isEmpty) {
      throw ArgumentError('First name cannot be empty');
    }
    if (lastname.trim().isEmpty) {
      throw ArgumentError('Last name cannot be empty');
    }
    return CopIndividual._(name: name.trim(), lastname: lastname.trim());
  }

  @override
  String get displayName => '$name $lastname';
}

/// A company, sent as `isCorporate: true` and `corporateName`.
final class CopCorporate extends CopHolder {
  final String corporateName;

  const CopCorporate._({required this.corporateName});

  factory CopCorporate({required String corporateName}) {
    if (corporateName.trim().isEmpty) {
      throw ArgumentError('Corporate name cannot be empty');
    }
    return CopCorporate._(corporateName: corporateName.trim());
  }

  @override
  String get displayName => corporateName;
}

/// Who a Colombian recipient pays.
@immutable
sealed class ColombiaPayee {
  const ColombiaPayee();

  String get displayName;
}

/// A holder and an email: everything the API requires to create a
/// recipient.
final class ColombiaContact extends ColombiaPayee {
  final CopHolder holder;
  final String email;

  const ColombiaContact._({required this.holder, required this.email});

  factory ColombiaContact({required CopHolder holder, required String email}) {
    if (!emailLooksValid(email)) {
      throw ArgumentError('Email is not valid');
    }
    return ColombiaContact._(holder: holder, email: email.trim());
  }

  @override
  String get displayName => holder.displayName;
}

/// A recipient the API holds without a full holder or an email, saved
/// before the API required them. It is listed with the name it has.
final class ColombiaNameOnly extends ColombiaPayee {
  final String name;

  const ColombiaNameOnly(this.name);

  @override
  String get displayName => name;
}

/// The payee of a recipient the API returned, from its raw fields.
ColombiaPayee colombiaPayeeFromSaved({
  bool? isCorporate,
  String? name,
  String? lastname,
  String? corporateName,
  String? email,
}) {
  String? text(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  final first = text(name);
  final last = text(lastname);
  final company = text(corporateName);
  final address = text(email);
  final corporate = isCorporate ?? company != null;

  final CopHolder? holder = switch ((corporate, first, last, company)) {
    (true, _, _, final String c) => CopCorporate(corporateName: c),
    (false, final String f, final String l, _) => CopIndividual(
      name: f,
      lastname: l,
    ),
    _ => null,
  };
  if (holder != null && address != null && emailLooksValid(address)) {
    return ColombiaContact(holder: holder, email: address);
  }
  return ColombiaNameOnly(
    holder?.displayName ??
        company ??
        [first, last].whereType<String>().join(' '),
  );
}

// ── PSE (Colombia)
@immutable
class PseColombiaDetails extends RecipientDetails {
  final ColombiaPayee payee;
  final String accountType;
  final String bankAccount;
  final String bankCode;
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
    required this.documentId,
    required this.documentType,
  });

  /// A new recipient: its payee must be a full [ColombiaContact].
  factory PseColombiaDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required ColombiaContact payee,
    required String accountType,
    required String bankAccount,
    required String bankCode,
    required String documentId,
    required String documentType,
  }) => PseColombiaDetails.saved(
    label: label,
    isDefault: isDefault,
    isOwner: isOwner,
    payee: payee,
    accountType: accountType,
    bankAccount: bankAccount,
    bankCode: bankCode,
    documentId: documentId,
    documentType: documentType,
  );

  /// A recipient the API already holds.
  factory PseColombiaDetails.saved({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required ColombiaPayee payee,
    required String accountType,
    required String bankAccount,
    required String bankCode,
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
      payee: payee,
      accountType: accountType.trim(),
      bankAccount: bankAccount.trim(),
      bankCode: bankCode.trim(),
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

  /// A new recipient: its payee must be a full [ColombiaContact].
  factory NequiColombiaDetails.create({
    String? label,
    bool isDefault = false,
    bool? isOwner,
    required ColombiaContact payee,
    required String phoneNumber,
    required String documentId,
    required String documentType,
  }) => NequiColombiaDetails.saved(
    label: label,
    isDefault: isDefault,
    isOwner: isOwner,
    payee: payee,
    phoneNumber: phoneNumber,
    documentId: documentId,
    documentType: documentType,
  );

  /// A recipient the API already holds.
  factory NequiColombiaDetails.saved({
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
      payee: payee,
      phoneNumber: phoneNumber.trim(),
      documentId: documentId.trim(),
      documentType: documentType.trim(),
    );
  }

  @override
  RecipientType get type => RecipientType.nequiColombia;
}
