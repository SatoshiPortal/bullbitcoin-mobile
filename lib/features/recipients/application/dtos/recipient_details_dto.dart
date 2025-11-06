import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:meta/meta.dart';

@immutable
class RecipientDetailsDto {
  // discriminator
  final RecipientType recipientType; // e.g. 'SEPA_EUR'

  // shared (RecipientDetails base)
  final String? label;
  final bool? isOwner; // optional - only meaningful for certain recipient types
  final bool? isDefault; // nullable so we can omit over the wire when false

  // ── Interac Email (CAD)
  final String? email;
  final String? name; // also used by some MXN types
  final String? securityQuestion;
  final String? securityAnswer;

  // ── Bill Payment (CAD)
  final String? payeeName;
  final String? payeeCode;
  final String? payeeAccountNumber;

  // ── Bank Transfer (CAD)
  final String? institutionNumber;
  final String? transitNumber;
  final String? accountNumber;
  final String? defaultComment;

  // ── SEPA (EUR)
  final String? iban;
  final bool? isCorporate;
  final String? firstname;
  final String? lastname;
  final String? corporateName;

  // ── SPEI (MXN)
  final String? clabe; // CLABE
  final String? institutionCode; // SMS/Card
  final String? phone; // SMS
  final String? debitcard; // Card

  // ── SINPE (CRC/USD)
  final String? ownerName; // IBAN USD/CRC, Movil
  final String? phoneNumber; // Movil

  // ── CBU/CVU (Argentina)
  final String? cbuCvu;

  const RecipientDetailsDto({
    required this.recipientType,
    this.isOwner,
    this.label,
    this.isDefault,
    // Interac
    this.email,
    this.name,
    this.securityQuestion,
    this.securityAnswer,
    // Bill Payment
    this.payeeName,
    this.payeeCode,
    this.payeeAccountNumber,
    // Bank Transfer
    this.institutionNumber,
    this.transitNumber,
    this.accountNumber,
    this.defaultComment,
    // SEPA
    this.iban,
    this.isCorporate,
    this.firstname,
    this.lastname,
    this.corporateName,
    // SPEI
    this.clabe,
    this.institutionCode,
    this.phone,
    this.debitcard,
    // SINPE
    this.ownerName,
    this.phoneNumber,
    // CBU/CVU Argentina
    this.cbuCvu,
  });

  // VO → DTO
  factory RecipientDetailsDto.fromDomain(RecipientDetails details) {
    final type = details.type;

    return switch (type) {
      // CANADA
      RecipientType.interacEmailCad => () {
        final d = details as InteracEmailCadDetails;
        return RecipientDetailsDto(
          recipientType: type,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          email: d.email,
          name: d.name,
          securityQuestion: d.securityQuestion,
          securityAnswer: d.securityAnswer,
        );
      }(),
      RecipientType.billPaymentCad => () {
        final d = details as BillPaymentCadDetails;
        return RecipientDetailsDto(
          recipientType: type,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          payeeName: d.payeeName,
          payeeCode: d.payeeCode,
          payeeAccountNumber: d.payeeAccountNumber,
        );
      }(),
      RecipientType.bankTransferCad => () {
        final d = details as BankTransferCadDetails;
        return RecipientDetailsDto(
          recipientType: type,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          institutionNumber: d.institutionNumber,
          transitNumber: d.transitNumber,
          accountNumber: d.accountNumber,
          name: d.name,
          defaultComment: d.defaultComment,
        );
      }(),

      // EUROPE
      RecipientType.sepaEur => () {
        final d = details as SepaEurDetails;
        return RecipientDetailsDto(
          recipientType: type,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          iban: d.iban,
          isCorporate: d.isCorporate,
          firstname: d.firstname,
          lastname: d.lastname,
          corporateName: d.corporateName,
        );
      }(),

      // MEXICO
      RecipientType.speiClabeMxn => () {
        final d = details as SpeiClabeMxnDetails;
        return RecipientDetailsDto(
          recipientType: type,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          clabe: d.clabe,
          name: d.name,
        );
      }(),
      RecipientType.speiSmsMxn => () {
        final d = details as SpeiSmsMxnDetails;
        return RecipientDetailsDto(
          recipientType: type,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          institutionCode: d.institutionCode,
          phone: d.phone,
          name: d.name,
        );
      }(),
      RecipientType.speiCardMxn => () {
        final d = details as SpeiCardMxnDetails;
        return RecipientDetailsDto(
          recipientType: type,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          institutionCode: d.institutionCode,
          debitcard: d.debitcard,
          name: d.name,
        );
      }(),

      // COSTA RICA
      RecipientType.sinpeIbanUsd => () {
        final d = details as SinpeIbanUsdDetails;
        return RecipientDetailsDto(
          recipientType: type,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          iban: d.iban,
          ownerName: d.ownerName,
        );
      }(),
      RecipientType.sinpeIbanCrc => () {
        final d = details as SinpeIbanCrcDetails;
        return RecipientDetailsDto(
          recipientType: type,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          iban: d.iban,
          ownerName: d.ownerName,
        );
      }(),
      RecipientType.sinpeMovilCrc => () {
        final d = details as SinpeMovilCrcDetails;
        return RecipientDetailsDto(
          recipientType: type,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          phoneNumber: d.phoneNumber,
          ownerName: d.ownerName,
        );
      }(),

      // ARGENTINA
      RecipientType.cbuCvuArgentina => () {
        final d = details as CbuCvuArgentinaDetails;
        return RecipientDetailsDto(
          recipientType: type,
          isOwner: d.isOwner,
          label: d.label,
          isDefault: d.isDefault,
          cbuCvu: d.cbuCvu,
          name: d.name,
        );
      }(),
      // TODO: Handle this case.
      RecipientType.pseColombia => () {
        return RecipientDetailsDto(recipientType: type);
      }(),
    };
  }

  // DTO → VO
  RecipientDetails toDomain() {
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
          securityQuestion: securityQuestion ?? 'What is your favorite color?',
          securityAnswer: securityAnswer ?? 'Orange',
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
        if (iban == null) throw StateError('iban is required for SEPA_EUR.');
        if (isCorporate == null) {
          throw StateError('isCorporate is required for SEPA_EUR.');
        }
        return SepaEurDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          iban: iban!,
          isCorporate: isCorporate!,
          firstname: firstname,
          lastname: lastname,
          corporateName: corporateName,
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
      case RecipientType.sinpeIbanUsd:
        if (iban == null) {
          throw StateError('iban is required for SINPE_IBAN_USD.');
        }
        if (ownerName == null) {
          throw StateError('ownerName is required for SINPE_IBAN_USD.');
        }
        return SinpeIbanUsdDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          iban: iban!,
          ownerName: ownerName!,
        );

      case RecipientType.sinpeIbanCrc:
        if (iban == null) {
          throw StateError('iban is required for SINPE_IBAN_CRC.');
        }
        if (ownerName == null) {
          throw StateError('ownerName is required for SINPE_IBAN_CRC.');
        }
        return SinpeIbanCrcDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          iban: iban!,
          ownerName: ownerName!,
        );

      case RecipientType.sinpeMovilCrc:
        if (phoneNumber == null) {
          throw StateError('phoneNumber is required for SINPE_MOVIL_CRC.');
        }
        if (ownerName == null) {
          throw StateError('ownerName is required for SINPE_MOVIL_CRC.');
        }
        return SinpeMovilCrcDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          phoneNumber: phoneNumber!,
          ownerName: ownerName!,
        );

      // ARGENTINA
      case RecipientType.cbuCvuArgentina:
        if (cbuCvu == null) {
          throw StateError('cbuCvu is required for CBU_CVU_ARGENTINA.');
        }
        if (name == null) {
          throw StateError('name is required for CBU_CVU_ARGENTINA.');
        }
        return CbuCvuArgentinaDetails.create(
          label: label,
          isDefault: def,
          isOwner: isOwner,
          cbuCvu: cbuCvu!,
          name: name!,
        );
      case RecipientType.pseColombia:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }
}
