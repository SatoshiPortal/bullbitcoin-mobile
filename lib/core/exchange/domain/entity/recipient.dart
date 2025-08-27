import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipient.freezed.dart';

enum WithdrawRecipientType {
  // CANADA
  interacEmailCad('INTERAC_EMAIL_CAD'),
  billPaymentCad('BILL_PAYMENT_CAD'),
  bankTransferCad('BANK_TRANSFER_CAD'),

  // EUROPE
  sepaEur('SEPA_EUR'),

  // MEXICO
  speiClabeMxn('SPEI_CLABE_MXN'),
  speiSmsMxn('SPEI_SMS_MXN'),
  speiCardMxn('SPEI_CARD_MXN'),

  // COSTA RICA
  sinpeIbanUsd('SINPE_IBAN_USD'),
  sinpeIbanCrc('SINPE_IBAN_CRC'),
  sinpeMovilCrc('SINPE_MOVIL_CRC');

  final String value;
  const WithdrawRecipientType(this.value);

  static WithdrawRecipientType fromValue(String value) {
    return WithdrawRecipientType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw Exception('Unknown WithdrawRecipientType: $value'),
    );
  }

  static WithdrawRecipientType fromCode(String code) {
    return WithdrawRecipientType.values.firstWhere(
      (e) => e.code == code,
      orElse:
          () => throw Exception('Unknown WithdrawRecipientType code: $code'),
    );
  }

  String get code => value;

  String get countryCode {
    switch (this) {
      case WithdrawRecipientType.interacEmailCad:
      case WithdrawRecipientType.billPaymentCad:
      case WithdrawRecipientType.bankTransferCad:
        return 'CA';
      case WithdrawRecipientType.sepaEur:
        return 'EU';
      case WithdrawRecipientType.speiClabeMxn:
      case WithdrawRecipientType.speiSmsMxn:
      case WithdrawRecipientType.speiCardMxn:
        return 'MX';
      case WithdrawRecipientType.sinpeIbanUsd:
      case WithdrawRecipientType.sinpeIbanCrc:
      case WithdrawRecipientType.sinpeMovilCrc:
        return 'CR';
    }
  }

  String get currencyCode {
    switch (this) {
      case WithdrawRecipientType.interacEmailCad:
      case WithdrawRecipientType.billPaymentCad:
      case WithdrawRecipientType.bankTransferCad:
        return 'CAD';
      case WithdrawRecipientType.sepaEur:
        return 'EUR';
      case WithdrawRecipientType.speiClabeMxn:
      case WithdrawRecipientType.speiSmsMxn:
      case WithdrawRecipientType.speiCardMxn:
        return 'MXN';
      case WithdrawRecipientType.sinpeIbanUsd:
        return 'USD';
      case WithdrawRecipientType.sinpeIbanCrc:
      case WithdrawRecipientType.sinpeMovilCrc:
        return 'CRC';
    }
  }

  String get displayName {
    switch (this) {
      case WithdrawRecipientType.interacEmailCad:
        return 'Interac e-Transfer';
      case WithdrawRecipientType.billPaymentCad:
        return 'Bill Payment';
      case WithdrawRecipientType.bankTransferCad:
        return 'Bank Transfer';
      case WithdrawRecipientType.sepaEur:
        return 'SEPA Transfer';
      case WithdrawRecipientType.speiClabeMxn:
        return 'SPEI CLABE';
      case WithdrawRecipientType.speiSmsMxn:
        return 'SPEI SMS';
      case WithdrawRecipientType.speiCardMxn:
        return 'SPEI Card';
      case WithdrawRecipientType.sinpeIbanUsd:
        return 'SINPE IBAN (USD)';
      case WithdrawRecipientType.sinpeIbanCrc:
        return 'SINPE IBAN (CRC)';
      case WithdrawRecipientType.sinpeMovilCrc:
        return 'SINPE Móvil';
    }
  }
}

@freezed
sealed class Recipient with _$Recipient {
  const factory Recipient.interacEmailCad({
    required String recipientId,
    required String userId,
    required int userNbr,
    required bool isOwner,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? label,
    String? name,
    String? email,
    String? securityQuestion,
    String? securityAnswer,
    bool? isDefault,
    String? defaultComment,
    String? firstname,
    String? lastname,
    bool? isCorporate,
    String? corporateName,
  }) = _RecipientInteracEmailCad;

  const factory Recipient.billPaymentCad({
    required String recipientId,
    required String userId,
    required int userNbr,
    required bool isOwner,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? label,
    bool? isDefault,
    String? payeeName,
    String? payeeCode,
    String? payeeAccountNumber,
    bool? isCorporate,
    String? corporateName,
  }) = _RecipientBillPaymentCad;

  const factory Recipient.bankTransferCad({
    required String recipientId,
    required String userId,
    required int userNbr,
    required bool isOwner,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,

    String? label,
    String? firstname,
    String? lastname,
    String? name,
    String? institutionNumber,
    String? transitNumber,
    String? accountNumber,
    bool? isDefault,
    String? ownerName,
    String? currency,
    String? defaultComment,
    String? payeeName,
    String? payeeCode,
    String? payeeAccountNumber,
    bool? isCorporate,
    String? corporateName,
  }) = _RecipientBankTransferCad;

  const factory Recipient.sepaEur({
    required String recipientId,
    required String userId,
    required int userNbr,
    required bool isOwner,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,

    String? label,
    String? firstname,
    String? lastname,
    String? name,
    String? iban,
    String? address,
    bool? isDefault,
    String? ownerName,
    String? currency,
    String? defaultComment,
    String? payeeName,
    String? payeeCode,
    String? payeeAccountNumber,
    bool? isCorporate,
    String? corporateName,
  }) = _RecipientSepaEur;

  const factory Recipient.speiClabeMxn({
    required String recipientId,
    required String userId,
    required int userNbr,
    required bool isOwner,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,

    String? label,
    String? firstname,
    String? lastname,
    String? name,
    String? clabe,
    String? institutionCode,
    bool? isDefault,
    String? ownerName,
    String? currency,
    String? defaultComment,
    String? payeeName,
    String? payeeCode,
    String? payeeAccountNumber,
    bool? isCorporate,
    String? corporateName,
  }) = _RecipientSpeiClabeMxn;

  const factory Recipient.speiSmsMxn({
    required String recipientId,
    required String userId,
    required int userNbr,
    required bool isOwner,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,

    String? label,
    String? firstname,
    String? lastname,
    String? name,
    String? phone,
    String? phoneNumber,
    String? institutionCode,
    bool? isDefault,
    String? ownerName,
    String? currency,
    String? defaultComment,
    String? payeeName,
    String? payeeCode,
    String? payeeAccountNumber,
    bool? isCorporate,
    String? corporateName,
  }) = _RecipientSpeiSmsMxn;

  const factory Recipient.speiCardMxn({
    required String recipientId,
    required String userId,
    required int userNbr,
    required bool isOwner,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,

    String? label,
    String? firstname,
    String? lastname,
    String? name,
    String? debitCard,
    String? institutionCode,
    bool? isDefault,
    String? ownerName,
    String? currency,
    String? defaultComment,
    String? payeeName,
    String? payeeCode,
    String? payeeAccountNumber,
    bool? isCorporate,
    String? corporateName,
  }) = _RecipientSpeiCardMxn;

  const factory Recipient.sinpeIbanUsd({
    required String recipientId,
    required String userId,
    required int userNbr,
    required bool isOwner,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,

    String? label,
    bool? isDefault,
    String? iban,
    String? ownerName,
    String? currency,
    bool? isCorporate,
    String? corporateName,
  }) = _RecipientSinpeIbanUsd;

  const factory Recipient.sinpeIbanCrc({
    required String recipientId,
    required String userId,
    required int userNbr,
    required bool isOwner,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,

    String? label,
    bool? isDefault,
    String? iban,
    String? ownerName,
    String? currency,
    bool? isCorporate,
    String? corporateName,
  }) = _RecipientSinpeIbanCrc;

  const factory Recipient.sinpeMovilCrc({
    required String recipientId,
    required String userId,
    required int userNbr,
    required bool isOwner,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,

    String? label,
    bool? isDefault,
    String? phoneNumber,
    String? ownerName,
    String? currency,
    String? defaultComment,
    bool? isCorporate,
    String? corporateName,
  }) = _RecipientSinpeMovilCrc;

  const Recipient._();

  String getRecipientFullName() {
    return when(
      interacEmailCad: (
        recipientId,
        userId,
        userNbr,
        isOwner,
        isArchived,
        createdAt,
        updatedAt,
        label,
        name,
        email,
        securityQuestion,
        securityAnswer,
        isDefault,
        defaultComment,
        firstname,
        lastname,
        isCorporate,
        corporateName,
      ) {
        if (isCorporate == true &&
            corporateName != null &&
            corporateName.isNotEmpty) {
          return corporateName;
        }
        if (name != null && name.isNotEmpty) return name;
        if (firstname != null && lastname != null) {
          return '$firstname $lastname';
        }
        if (firstname != null) return firstname;
        if (lastname != null) return lastname;
        if (email != null) return email;
        return 'Interac e-Transfer';
      },
      billPaymentCad: (
        recipientId,
        userId,
        userNbr,
        isOwner,
        isArchived,
        createdAt,
        updatedAt,
        label,
        isDefault,
        payeeName,
        payeeCode,
        payeeAccountNumber,
        isCorporate,
        corporateName,
      ) {
        if (isCorporate == true &&
            corporateName != null &&
            corporateName.isNotEmpty) {
          return corporateName;
        }
        if (payeeName != null && payeeName.isNotEmpty) return payeeName;
        if (label != null && label.isNotEmpty) return label;
        return 'Bill Payment';
      },
      bankTransferCad: (
        recipientId,
        userId,
        userNbr,
        isOwner,
        isArchived,
        createdAt,
        updatedAt,
        label,
        firstname,
        lastname,
        name,
        institutionNumber,
        transitNumber,
        accountNumber,
        isDefault,
        ownerName,
        currency,
        defaultComment,
        payeeName,
        payeeCode,
        payeeAccountNumber,
        isCorporate,
        corporateName,
      ) {
        if (isCorporate == true &&
            corporateName != null &&
            corporateName.isNotEmpty) {
          return corporateName;
        }
        if (name != null && name.isNotEmpty) return name;
        if (ownerName != null && ownerName.isNotEmpty) return ownerName;
        if (firstname != null && lastname != null) {
          return '$firstname $lastname';
        }
        if (firstname != null) return firstname;
        if (lastname != null) return lastname;
        if (label != null && label.isNotEmpty) return label;
        return 'Bank Transfer';
      },
      sepaEur: (
        recipientId,
        userId,
        userNbr,
        isOwner,
        isArchived,
        createdAt,
        updatedAt,
        label,
        firstname,
        lastname,
        name,
        iban,
        address,
        isDefault,
        ownerName,
        currency,
        defaultComment,
        payeeName,
        payeeCode,
        payeeAccountNumber,
        isCorporate,
        corporateName,
      ) {
        if (isCorporate == true &&
            corporateName != null &&
            corporateName.isNotEmpty) {
          return corporateName;
        }
        if (name != null && name.isNotEmpty) return name;
        if (firstname != null && lastname != null) {
          return '$firstname $lastname';
        }
        if (firstname != null) return firstname;
        if (lastname != null) return lastname;
        if (label != null && label.isNotEmpty) return label;
        return 'SEPA Transfer';
      },
      speiClabeMxn: (
        recipientId,
        userId,
        userNbr,
        isOwner,
        isArchived,
        createdAt,
        updatedAt,
        label,
        firstname,
        lastname,
        name,
        clabe,
        institutionCode,
        isDefault,
        ownerName,
        currency,
        defaultComment,
        payeeName,
        payeeCode,
        payeeAccountNumber,
        isCorporate,
        corporateName,
      ) {
        if (isCorporate == true &&
            corporateName != null &&
            corporateName.isNotEmpty) {
          return corporateName;
        }
        if (name != null && name.isNotEmpty) return name;
        if (firstname != null && lastname != null) {
          return '$firstname $lastname';
        }
        if (firstname != null) return firstname;
        if (lastname != null) return lastname;
        if (label != null && label.isNotEmpty) return label;
        return 'SPEI CLABE';
      },
      speiSmsMxn: (
        recipientId,
        userId,
        userNbr,
        isOwner,
        isArchived,
        createdAt,
        updatedAt,
        label,
        firstname,
        lastname,
        name,
        phone,
        phoneNumber,
        institutionCode,
        isDefault,
        ownerName,
        currency,
        defaultComment,
        payeeName,
        payeeCode,
        payeeAccountNumber,
        isCorporate,
        corporateName,
      ) {
        if (isCorporate == true &&
            corporateName != null &&
            corporateName.isNotEmpty) {
          return corporateName;
        }
        if (name != null && name.isNotEmpty) return name;
        if (firstname != null && lastname != null) {
          return '$firstname $lastname';
        }
        if (firstname != null) return firstname;
        if (lastname != null) return lastname;
        if (label != null && label.isNotEmpty) return label;
        return 'SPEI SMS';
      },
      speiCardMxn: (
        recipientId,
        userId,
        userNbr,
        isOwner,
        isArchived,
        createdAt,
        updatedAt,
        label,
        firstname,
        lastname,
        name,
        debitCard,
        institutionCode,
        isDefault,
        ownerName,
        currency,
        defaultComment,
        payeeName,
        payeeCode,
        payeeAccountNumber,
        isCorporate,
        corporateName,
      ) {
        if (isCorporate == true &&
            corporateName != null &&
            corporateName.isNotEmpty) {
          return corporateName;
        }
        if (name != null && name.isNotEmpty) return name;
        if (firstname != null && lastname != null) {
          return '$firstname $lastname';
        }
        if (firstname != null) return firstname;
        if (lastname != null) return lastname;
        if (label != null && label.isNotEmpty) return label;
        return 'SPEI Card';
      },
      sinpeIbanUsd: (
        recipientId,
        userId,
        userNbr,
        isOwner,
        isArchived,
        createdAt,
        updatedAt,
        label,
        isDefault,
        iban,
        ownerName,
        currency,
        isCorporate,
        corporateName,
      ) {
        if (ownerName != null && ownerName.isNotEmpty) return ownerName;
        if (label != null && label.isNotEmpty) return label;
        return 'SINPE IBAN (USD)';
      },
      sinpeIbanCrc: (
        recipientId,
        userId,
        userNbr,
        isOwner,
        isArchived,
        createdAt,
        updatedAt,
        label,
        isDefault,
        iban,
        ownerName,
        currency,
        isCorporate,
        corporateName,
      ) {
        if (ownerName != null && ownerName.isNotEmpty) return ownerName;
        if (label != null && label.isNotEmpty) return label;
        return 'SINPE IBAN (CRC)';
      },
      sinpeMovilCrc: (
        recipientId,
        userId,
        userNbr,
        isOwner,
        isArchived,
        createdAt,
        updatedAt,
        label,
        isDefault,
        phoneNumber,
        ownerName,
        currency,
        defaultComment,
        isCorporate,
        corporateName,
      ) {
        if (ownerName != null && ownerName.isNotEmpty) return ownerName;
        if (label != null && label.isNotEmpty) return label;
        return 'SINPE Móvil';
      },
    );
  }

  WithdrawRecipientType get recipientType {
    return switch (this) {
      _RecipientInteracEmailCad() => WithdrawRecipientType.interacEmailCad,
      _RecipientBillPaymentCad() => WithdrawRecipientType.billPaymentCad,
      _RecipientBankTransferCad() => WithdrawRecipientType.bankTransferCad,
      _RecipientSepaEur() => WithdrawRecipientType.sepaEur,
      _RecipientSpeiClabeMxn() => WithdrawRecipientType.speiClabeMxn,
      _RecipientSpeiSmsMxn() => WithdrawRecipientType.speiSmsMxn,
      _RecipientSpeiCardMxn() => WithdrawRecipientType.speiCardMxn,
      _RecipientSinpeIbanUsd() => WithdrawRecipientType.sinpeIbanUsd,
      _RecipientSinpeIbanCrc() => WithdrawRecipientType.sinpeIbanCrc,
      _RecipientSinpeMovilCrc() => WithdrawRecipientType.sinpeMovilCrc,
    };
  }
}
