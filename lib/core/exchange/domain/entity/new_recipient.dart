import 'package:freezed_annotation/freezed_annotation.dart';

part 'new_recipient.freezed.dart';

@freezed
sealed class NewRecipient with _$NewRecipient {
  const factory NewRecipient.interacEmailCad({
    String? label,
    required String email,
    required String name,
    @Default('What is your favorite color?') String securityQuestion,
    @Default('Orange') String securityAnswer,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientInteracEmailCad;

  const factory NewRecipient.billPaymentCad({
    String? label,
    required String payeeName,
    required String payeeCode,
    required String payeeAccountNumber,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientBillPaymentCad;

  const factory NewRecipient.bankTransferCad({
    String? label,
    required String institutionNumber,
    required String transitNumber,
    required String accountNumber,
    required String name,
    String? defaultComment,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientBankTransferCad;

  const factory NewRecipient.sepaEur({
    String? label,
    required String iban,
    required bool isCorporate,
    String? firstname,
    String? lastname,
    String? corporateName,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientSepaEur;

  const factory NewRecipient.speiClabeMxn({
    String? label,
    required String clabe,
    required String name,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientSpeiClabeMxn;

  const factory NewRecipient.speiSmsMxn({
    String? label,
    required String institutionCode,
    required String phone,
    required String name,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientSpeiSmsMxn;

  const factory NewRecipient.speiCardMxn({
    String? label,
    required String institutionCode,
    required String debitcard,
    required String name,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientSpeiCardMxn;

  const factory NewRecipient.sinpeIbanUsd({
    String? label,
    required String iban,
    required String ownerName,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientSinpeIbanUsd;

  const factory NewRecipient.sinpeIbanCrc({
    String? label,
    required String iban,
    required String ownerName,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientSinpeIbanCrc;

  const factory NewRecipient.sinpeMovilCrc({
    String? label,
    required String phoneNumber,
    required String ownerName,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientSinpeMovilCrc;

  const NewRecipient._();

  String get recipientTypeFiat {
    return switch (this) {
      _NewRecipientInteracEmailCad() => 'INTERAC_EMAIL_CAD',
      _NewRecipientBillPaymentCad() => 'BILL_PAYMENT_CAD',
      _NewRecipientBankTransferCad() => 'BANK_TRANSFER_CAD',
      _NewRecipientSepaEur() => 'SEPA_EUR',
      _NewRecipientSpeiClabeMxn() => 'SPEI_CLABE_MXN',
      _NewRecipientSpeiSmsMxn() => 'SPEI_SMS_MXN',
      _NewRecipientSpeiCardMxn() => 'SPEI_CARD_MXN',
      _NewRecipientSinpeIbanUsd() => 'SINPE_IBAN_USD',
      _NewRecipientSinpeIbanCrc() => 'SINPE_IBAN_CRC',
      _NewRecipientSinpeMovilCrc() => 'SINPE_MOVIL_CRC',
    };
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'recipientTypeFiat': recipientTypeFiat,
      'label': when(
        interacEmailCad:
            (
              label,
              email,
              name,
              securityQuestion,
              securityAnswer,
              isDefault,
              isArchived,
              isOwner,
            ) => label,
        billPaymentCad:
            (
              label,
              payeeName,
              payeeCode,
              payeeAccountNumber,
              isDefault,
              isArchived,
              isOwner,
            ) => label,
        bankTransferCad:
            (
              label,
              institutionNumber,
              transitNumber,
              accountNumber,
              name,
              defaultComment,
              isDefault,
              isArchived,
              isOwner,
            ) => label,
        sepaEur:
            (
              label,
              iban,
              isCorporate,
              firstname,
              lastname,
              corporateName,
              isDefault,
              isArchived,
              isOwner,
            ) => label,
        speiClabeMxn:
            (label, clabe, name, isDefault, isArchived, isOwner) => label,
        speiSmsMxn:
            (
              label,
              institutionCode,
              phone,
              name,

              isDefault,
              isArchived,
              isOwner,
            ) => label,
        speiCardMxn:
            (
              label,
              institutionCode,
              debitcard,
              name,

              isDefault,
              isArchived,
              isOwner,
            ) => label,
        sinpeIbanUsd:
            (label, iban, ownerName, isDefault, isArchived, isOwner) => label,
        sinpeIbanCrc:
            (label, iban, ownerName, isDefault, isArchived, isOwner) => label,
        sinpeMovilCrc:
            (label, phoneNumber, ownerName, isDefault, isArchived, isOwner) =>
                label,
      ),
      'isDefault': when(
        interacEmailCad:
            (
              label,
              email,
              name,
              securityQuestion,
              securityAnswer,
              isDefault,
              isArchived,
              isOwner,
            ) => isDefault,
        billPaymentCad:
            (
              label,
              payeeName,
              payeeCode,
              payeeAccountNumber,
              isDefault,
              isArchived,
              isOwner,
            ) => isDefault,
        bankTransferCad:
            (
              label,
              institutionNumber,
              transitNumber,
              accountNumber,
              name,
              defaultComment,
              isDefault,
              isArchived,
              isOwner,
            ) => isDefault,
        sepaEur:
            (
              label,
              iban,
              isCorporate,
              firstname,
              lastname,
              corporateName,
              isDefault,
              isArchived,
              isOwner,
            ) => isDefault,
        speiClabeMxn:
            (label, clabe, name, isDefault, isArchived, isOwner) => isDefault,
        speiSmsMxn:
            (
              label,
              institutionCode,
              phone,
              name,
              isDefault,
              isArchived,
              isOwner,
            ) => isDefault,
        speiCardMxn:
            (
              label,
              institutionCode,
              debitcard,
              name,
              isDefault,
              isArchived,
              isOwner,
            ) => isDefault,
        sinpeIbanUsd:
            (label, iban, ownerName, isDefault, isArchived, isOwner) =>
                isDefault,
        sinpeIbanCrc:
            (label, iban, ownerName, isDefault, isArchived, isOwner) =>
                isDefault,
        sinpeMovilCrc:
            (label, phoneNumber, ownerName, isDefault, isArchived, isOwner) =>
                isDefault,
      ),
      'isArchived': when(
        interacEmailCad:
            (
              label,
              email,
              name,
              securityQuestion,
              securityAnswer,
              isDefault,
              isArchived,
              isOwner,
            ) => isArchived,
        billPaymentCad:
            (
              label,
              payeeName,
              payeeCode,
              payeeAccountNumber,
              isDefault,
              isArchived,
              isOwner,
            ) => isArchived,
        bankTransferCad:
            (
              label,
              institutionNumber,
              transitNumber,
              accountNumber,
              name,
              defaultComment,
              isDefault,
              isArchived,
              isOwner,
            ) => isArchived,
        sepaEur:
            (
              label,
              iban,
              isCorporate,
              firstname,
              lastname,
              corporateName,
              isDefault,
              isArchived,
              isOwner,
            ) => isArchived,
        speiClabeMxn:
            (label, clabe, name, isDefault, isArchived, isOwner) => isArchived,
        speiSmsMxn:
            (
              label,
              institutionCode,
              phone,
              name,
              isDefault,
              isArchived,
              isOwner,
            ) => isArchived,
        speiCardMxn:
            (
              label,
              institutionCode,
              debitcard,
              name,
              isDefault,
              isArchived,
              isOwner,
            ) => isArchived,
        sinpeIbanUsd:
            (label, iban, ownerName, isDefault, isArchived, isOwner) =>
                isArchived,
        sinpeIbanCrc:
            (label, iban, ownerName, isDefault, isArchived, isOwner) =>
                isArchived,
        sinpeMovilCrc:
            (label, phoneNumber, ownerName, isDefault, isArchived, isOwner) =>
                isArchived,
      ),
      'isOwner': when(
        interacEmailCad:
            (
              label,
              email,
              name,
              securityQuestion,
              securityAnswer,
              isDefault,
              isArchived,
              isOwner,
            ) => isOwner,
        billPaymentCad:
            (
              label,
              payeeName,
              payeeCode,
              payeeAccountNumber,
              isDefault,
              isArchived,
              isOwner,
            ) => isOwner,
        bankTransferCad:
            (
              label,
              institutionNumber,
              transitNumber,
              accountNumber,
              name,
              defaultComment,
              isDefault,
              isArchived,
              isOwner,
            ) => isOwner,
        sepaEur:
            (
              label,
              iban,
              isCorporate,
              firstname,
              lastname,
              corporateName,
              isDefault,
              isArchived,
              isOwner,
            ) => isOwner,
        speiClabeMxn:
            (label, clabe, name, isDefault, isArchived, isOwner) => isOwner,
        speiSmsMxn:
            (
              label,
              institutionCode,
              phone,
              name,
              isDefault,
              isArchived,
              isOwner,
            ) => isOwner,
        speiCardMxn:
            (
              label,
              institutionCode,
              debitcard,
              name,
              isDefault,
              isArchived,
              isOwner,
            ) => isOwner,
        sinpeIbanUsd:
            (label, iban, ownerName, isDefault, isArchived, isOwner) => isOwner,
        sinpeIbanCrc:
            (label, iban, ownerName, isDefault, isArchived, isOwner) => isOwner,
        sinpeMovilCrc:
            (label, phoneNumber, ownerName, isDefault, isArchived, isOwner) =>
                isOwner,
      ),
    };

    // Add type-specific fields
    when(
      interacEmailCad: (
        label,
        email,
        name,
        securityQuestion,
        securityAnswer,
        isDefault,
        isArchived,
        isOwner,
      ) {
        data['email'] = email;
        data['name'] = name;
        data['securityQuestion'] = securityQuestion;
        data['securityAnswer'] = securityAnswer;
      },
      billPaymentCad: (
        label,
        payeeName,
        payeeCode,
        payeeAccountNumber,
        isDefault,
        isArchived,
        isOwner,
      ) {
        data['payeeName'] = payeeName;
        data['payeeCode'] = payeeCode;
        data['payeeAccountNumber'] = payeeAccountNumber;
      },
      bankTransferCad: (
        label,
        institutionNumber,
        transitNumber,
        accountNumber,
        name,
        defaultComment,
        isDefault,
        isArchived,
        isOwner,
      ) {
        data['institutionNumber'] = institutionNumber;
        data['transitNumber'] = transitNumber;
        data['accountNumber'] = accountNumber;
        data['name'] = name;
        data['defaultComment'] = defaultComment;
      },
      sepaEur: (
        label,
        iban,
        isCorporate,
        firstname,
        lastname,
        corporateName,
        isDefault,
        isArchived,
        isOwner,
      ) {
        data['iban'] = iban;
        data['isCorporate'] = isCorporate;
        if (firstname != null) data['firstname'] = firstname;
        if (lastname != null) data['lastname'] = lastname;
        if (corporateName != null) data['corporateName'] = corporateName;
      },
      speiClabeMxn: (label, clabe, name, isDefault, isArchived, isOwner) {
        data['clabe'] = clabe;
        data['name'] = name;
      },
      speiSmsMxn: (
        label,
        institutionCode,
        phone,
        name,

        isDefault,
        isArchived,
        isOwner,
      ) {
        data['institutionCode'] = institutionCode;
        data['phone'] = phone;
        data['name'] = name;
      },
      speiCardMxn: (
        label,
        institutionCode,
        debitcard,
        name,

        isDefault,
        isArchived,
        isOwner,
      ) {
        data['institutionCode'] = institutionCode;
        data['debitcard'] = debitcard;
        data['name'] = name;
      },
      sinpeIbanUsd: (label, iban, ownerName, isDefault, isArchived, isOwner) {
        data['iban'] = iban;
        data['ownerName'] = ownerName;
      },
      sinpeIbanCrc: (label, iban, ownerName, isDefault, isArchived, isOwner) {
        data['iban'] = iban;
        data['ownerName'] = ownerName;
      },
      sinpeMovilCrc: (
        label,
        phoneNumber,
        ownerName,
        isDefault,
        isArchived,
        isOwner,
      ) {
        data['phoneNumber'] = phoneNumber;
        data['ownerName'] = ownerName;
      },
    );

    return data;
  }
}
