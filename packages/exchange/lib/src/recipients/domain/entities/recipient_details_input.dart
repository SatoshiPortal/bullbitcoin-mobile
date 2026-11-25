import 'package:exchange/src/recipients/domain/entities/recipient_details.dart';
import 'package:exchange/src/recipients/domain/entities/recipient_type.dart';
import 'package:exchange/src/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:exchange/src/recipients/domain/recipient_field_checks.dart';
import 'package:meta/meta.dart';

@immutable
class RecipientDetailsInput {
  // discriminator
  final RecipientType recipientType; // e.g. 'SEPA_EUR'
  // shared fields
  final String? label;
  final bool? isOwner;
  final bool? isDefault;
  // specific fields for recipient types
  final String? email;
  final String? name;
  final String? securityQuestion;
  final String? securityAnswer;
  final String? payeeName;
  final String? payeeCode;
  final String? payeeAccountNumber;
  final String? institutionNumber;
  final String? transitNumber;
  final String? accountNumber;
  final String? defaultComment;
  final String? iban;
  final bool? isCorporate;
  final String? firstname;
  final String? lastname;
  final String? corporateName;
  final SepaVirtualPayeeStatus virtualPayeeStatus;
  final String? clabe;
  final String? institutionCode;
  final String? phone;
  final String? debitcard;
  final String? ownerName;
  final String? phoneNumber;
  final String? claveUniform;
  final String? bankCode;
  final String? accountType;
  final String? bankAccount;
  final String? bankName;
  final String? documentId;
  final String? documentType;

  const RecipientDetailsInput({
    required this.recipientType,
    this.isOwner,
    this.label,
    this.isDefault,
    this.email,
    this.name,
    this.securityQuestion,
    this.securityAnswer,
    this.payeeName,
    this.payeeCode,
    this.payeeAccountNumber,
    this.institutionNumber,
    this.transitNumber,
    this.accountNumber,
    this.defaultComment,
    this.iban,
    this.isCorporate,
    this.firstname,
    this.lastname,
    this.corporateName,
    this.virtualPayeeStatus = SepaVirtualPayeeStatus.absent,
    this.clabe,
    this.institutionCode,
    this.phone,
    this.debitcard,
    this.ownerName,
    this.phoneNumber,
    this.claveUniform,
    this.bankCode,
    this.accountType,
    this.bankAccount,
    this.bankName,
    this.documentId,
    this.documentType,
  });

  /// The same input for an account owned as [isOwner] says. The recipient
  /// pick step applies its filter's owner here, so a recipient created
  /// under an "own" filter is created as owned (RCP-9).
  RecipientDetailsInput withOwner(bool isOwner) => RecipientDetailsInput(
    recipientType: recipientType,
    isOwner: isOwner,
    label: label,
    isDefault: isDefault,
    email: email,
    name: name,
    securityQuestion: securityQuestion,
    securityAnswer: securityAnswer,
    payeeName: payeeName,
    payeeCode: payeeCode,
    payeeAccountNumber: payeeAccountNumber,
    institutionNumber: institutionNumber,
    transitNumber: transitNumber,
    accountNumber: accountNumber,
    defaultComment: defaultComment,
    iban: iban,
    isCorporate: isCorporate,
    firstname: firstname,
    lastname: lastname,
    corporateName: corporateName,
    virtualPayeeStatus: virtualPayeeStatus,
    clabe: clabe,
    institutionCode: institutionCode,
    phone: phone,
    debitcard: debitcard,
    ownerName: ownerName,
    phoneNumber: phoneNumber,
    claveUniform: claveUniform,
    bankCode: bankCode,
    accountType: accountType,
    bankAccount: bankAccount,
    bankName: bankName,
    documentId: documentId,
    documentType: documentType,
  );

  /// [toDomain], or null for a missing or invalid field instead of a throw.
  RecipientDetails? tryToDomain() {
    // toDomain throws StateError for a missing field, ArgumentError from the
    // value objects, and a TypeError on a null it asserts away.
    try {
      return toDomain();
    } on Object {
      return null;
    }
  }

  /// The details of a new recipient, with every field the API requires to
  /// create it. Throws [StateError] for a missing field and [ArgumentError]
  /// for an invalid one.
  RecipientDetails toDomain() => _toDomain(stored: false);

  /// The details of a recipient the server returned. Unlike [toDomain], it
  /// keeps a Colombian recipient saved before the API required the last
  /// name and email ([ColombiaNameOnly]).
  RecipientDetails toStoredDomain() => _toDomain(stored: true);

  /// The Colombian payee of this input: a [ColombiaContact] when the holder
  /// and email are complete; for a [stored] recipient without them, a
  /// [ColombiaNameOnly] under the name it has.
  ColombiaPayee _colombiaPayee(String type, {required bool stored}) {
    String? text(String? value) =>
        value == null || value.trim().isEmpty ? null : value;
    final corporate = text(corporateName);
    final first = text(name);
    final last = text(lastname);
    final mail = text(email);
    final ColombiaAccountHolder? holder = isCorporate ?? false
        ? (corporate == null
              ? null
              : ColombiaCorporate.create(corporateName: corporate))
        : (first == null || last == null
              ? null
              : ColombiaIndividual.create(firstName: first, lastName: last));
    if (holder != null && mail != null) {
      if (!stored && !emailLooksValid(mail)) {
        throw ArgumentError('email is not an address for $type.');
      }
      return ColombiaContact.create(holder: holder, email: mail);
    }
    if (!stored) {
      if (holder == null) {
        throw StateError(
          isCorporate ?? false
              ? 'corporateName is required for a corporate $type.'
              : 'name and lastname are required for $type.',
        );
      }
      throw StateError('email is required for $type.');
    }
    final shown = holder?.displayName ?? first ?? corporate;
    if (shown == null) throw StateError('name is required for $type.');
    return ColombiaNameOnly.create(
      name: last == null || holder != null ? shown : '$shown $last',
    );
  }

  RecipientDetails _toDomain({required bool stored}) {
    final def = isDefault ?? false;

    switch (recipientType) {
      // CANADA
      case RecipientType.interacEmailCad:
        if (email == null) {
          throw StateError('email is required for INTERAC_EMAIL_CAD.');
        }
        if (name == null) {
          throw StateError('name is required for INTERAC_EMAIL_CAD.');
        }
        return InteracEmailCadDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          email: email!,
          name: name!,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
        );

      case RecipientType.billPaymentCad:
        if (payeeName == null) {
          throw StateError('payeeName is required for BILL_PAYMENT_CAD.');
        }
        if (payeeCode == null) {
          throw StateError('payeeCode is required for BILL_PAYMENT_CAD.');
        }
        if (payeeAccountNumber == null) {
          throw StateError(
            'payeeAccountNumber is required for BILL_PAYMENT_CAD.',
          );
        }
        return BillPaymentCadDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          payeeName: payeeName!,
          payeeCode: payeeCode!,
          payeeAccountNumber: payeeAccountNumber!,
        );

      case RecipientType.bankTransferCad:
        if (institutionNumber == null) {
          throw StateError(
            'institutionNumber is required for BANK_TRANSFER_CAD.',
          );
        }
        if (transitNumber == null) {
          throw StateError('transitNumber is required for BANK_TRANSFER_CAD.');
        }
        if (accountNumber == null) {
          throw StateError('accountNumber is required for BANK_TRANSFER_CAD.');
        }
        if (name == null) {
          throw StateError('name is required for BANK_TRANSFER_CAD.');
        }
        return BankTransferCadDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          institutionNumber: institutionNumber!,
          transitNumber: transitNumber!,
          accountNumber: accountNumber!,
          name: name!,
          defaultComment: defaultComment,
        );

      // EUROPE
      case RecipientType.sepaEur:
      case RecipientType.confidentialSepaEur:
        if (iban == null) throw StateError('iban is required for SEPA_EUR.');
        final inferredIsCorporate =
            isCorporate ??
            (corporateName != null && corporateName!.trim().isNotEmpty);
        return SepaEurDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          iban: iban!,
          isCorporate: inferredIsCorporate,
          firstname: firstname,
          lastname: lastname,
          corporateName: corporateName,
          virtualPayeeStatus: virtualPayeeStatus,
          isConfidential: recipientType == RecipientType.confidentialSepaEur,
        );

      // MEXICO
      case RecipientType.speiClabeMxn:
        if (clabe == null) {
          throw StateError('clabe is required for SPEI_CLABE_MXN.');
        }
        if (name == null) {
          throw StateError('name is required for SPEI_CLABE_MXN.');
        }
        return SpeiClabeMxnDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          clabe: clabe!,
          name: name!,
        );

      case RecipientType.speiSmsMxn:
        if (institutionCode == null) {
          throw StateError('institutionCode is required for SPEI_SMS_MXN.');
        }
        if (phone == null) {
          throw StateError('phone is required for SPEI_SMS_MXN.');
        }
        if (name == null) {
          throw StateError('name is required for SPEI_SMS_MXN.');
        }
        return SpeiSmsMxnDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          institutionCode: institutionCode!,
          phone: phone!,
          name: name!,
        );

      case RecipientType.speiCardMxn:
        if (institutionCode == null) {
          throw StateError('institutionCode is required for SPEI_CARD_MXN.');
        }
        if (debitcard == null) {
          throw StateError('debitcard is required for SPEI_CARD_MXN.');
        }
        if (name == null) {
          throw StateError('name is required for SPEI_CARD_MXN.');
        }
        return SpeiCardMxnDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          institutionCode: institutionCode!,
          debitcard: debitcard!,
          name: name!,
        );

      // COSTA RICA
      // ownerName is nullable by design for the SINPE types: the server fills it
      // from a Ridivi lookup that can fail or be empty on older records.
      // Requiring it here silently dropped those recipients (#2529).
      case RecipientType.sinpeIbanUsd:
        if (iban == null) {
          throw StateError('iban is required for SINPE_IBAN_USD.');
        }
        return SinpeIbanUsdDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          iban: iban!,
          ownerName: ownerName,
        );

      case RecipientType.sinpeIbanCrc:
        if (iban == null) {
          throw StateError('iban is required for SINPE_IBAN_CRC.');
        }
        return SinpeIbanCrcDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          iban: iban!,
          ownerName: ownerName,
        );

      case RecipientType.sinpeMovilCrc:
        if (phoneNumber == null) {
          throw StateError('phoneNumber is required for SINPE_MOVIL_CRC.');
        }
        return SinpeMovilCrcDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          phoneNumber: phoneNumber!,
          ownerName: ownerName,
        );

      // ARGENTINA
      case RecipientType.bankAccountArgentina:
        if (name == null) {
          throw StateError('name is required for CBU_CVU_ARGENTINA.');
        }
        return BankAccountArgentinaDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          claveUniform: claveUniform ?? '',
          name: name!,
        );
      case RecipientType.pseColombia:
        if (accountType == null) {
          throw StateError('accountType is required for PSE_COLOMBIA.');
        }
        if (bankAccount == null) {
          throw StateError('bankAccount is required for PSE_COLOMBIA.');
        }
        if (bankCode == null) {
          throw StateError('bankCode is required for PSE_COLOMBIA.');
        }
        if (documentId == null) {
          throw StateError('documentId is required for PSE_COLOMBIA.');
        }
        if (documentType == null) {
          throw StateError('documentType is required for PSE_COLOMBIA.');
        }
        return PseColombiaDetails.stored(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          payee: _colombiaPayee('PSE_COLOMBIA', stored: stored),
          accountType: accountType!,
          bankAccount: bankAccount!,
          bankCode: bankCode!,
          bankName: bankName ?? '',
          documentId: documentId!,
          documentType: documentType!,
        );
      case RecipientType.nequiColombia:
        // The API's field is bankAccount; the form calls it phoneNumber.
        final phone = phoneNumber ?? bankAccount;
        if (phone == null) {
          throw StateError('phoneNumber is required for NEQUI_COLOMBIA.');
        }
        if (documentId == null) {
          throw StateError('documentId is required for NEQUI_COLOMBIA.');
        }
        if (documentType == null) {
          throw StateError('documentType is required for NEQUI_COLOMBIA.');
        }
        return NequiColombiaDetails.stored(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          payee: _colombiaPayee('NEQUI_COLOMBIA', stored: stored),
          phoneNumber: phone,
          documentId: documentId!,
          documentType: documentType!,
        );
    }
  }
}
