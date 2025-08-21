import 'package:bb_mobile/core/exchange/domain/entity/new_recipient.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'new_recipient_model.freezed.dart';
part 'new_recipient_model.g.dart';

@freezed
sealed class NewRecipientModel with _$NewRecipientModel {
  const factory NewRecipientModel.interacEmailCad({
    String? label,
    required String email,
    required String name,
    @Default('What is your favorite color?') String securityQuestion,
    @Default('Orange') String securityAnswer,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientModelInteracEmailCad;

  const factory NewRecipientModel.billPaymentCad({
    String? label,
    required String payeeName,
    required String payeeCode,
    required String payeeAccountNumber,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientModelBillPaymentCad;

  const factory NewRecipientModel.bankTransferCad({
    String? label,
    required String institutionNumber,
    required String transitNumber,
    required String accountNumber,
    required String name,
    String? defaultComment,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientModelBankTransferCad;

  const factory NewRecipientModel.sepaEur({
    String? label,
    required String iban,
    required bool isCorporate,
    String? firstname,
    String? lastname,
    String? corporateName,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientModelSepaEur;

  const factory NewRecipientModel.speiClabeMxn({
    String? label,
    required String clabe,
    required String name,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientModelSpeiClabeMxn;

  const factory NewRecipientModel.speiSmsMxn({
    String? label,
    required String institutionCode,
    required String phone,
    required String name,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientModelSpeiSmsMxn;

  const factory NewRecipientModel.speiCardMxn({
    String? label,
    required String institutionCode,
    required String debitcard,
    required String name,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientModelSpeiCardMxn;

  const factory NewRecipientModel.sinpeIbanUsd({
    String? label,
    required String iban,
    required String ownerName,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientModelSinpeIbanUsd;

  const factory NewRecipientModel.sinpeIbanCrc({
    String? label,
    required String iban,
    required String ownerName,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientModelSinpeIbanCrc;

  const factory NewRecipientModel.sinpeMovilCrc({
    String? label,
    required String phoneNumber,
    required String ownerName,
    @Default(false) bool isDefault,
    @Default(false) bool isArchived,
    required bool isOwner,
  }) = _NewRecipientModelSinpeMovilCrc;

  factory NewRecipientModel.fromJson(Map<String, dynamic> json) =>
      _$NewRecipientModelFromJson(json);

  factory NewRecipientModel.fromEntity(NewRecipient entity) {
    return entity.when(
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
          ) => NewRecipientModel.interacEmailCad(
            label: label,
            email: email,
            name: name,
            securityQuestion: securityQuestion,
            securityAnswer: securityAnswer,
            isDefault: isDefault,
            isArchived: isArchived,
            isOwner: isOwner,
          ),
      billPaymentCad:
          (
            label,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isDefault,
            isArchived,
            isOwner,
          ) => NewRecipientModel.billPaymentCad(
            label: label,
            payeeName: payeeName,
            payeeCode: payeeCode,
            payeeAccountNumber: payeeAccountNumber,
            isDefault: isDefault,
            isArchived: isArchived,
            isOwner: isOwner,
          ),
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
          ) => NewRecipientModel.bankTransferCad(
            label: label,
            institutionNumber: institutionNumber,
            transitNumber: transitNumber,
            accountNumber: accountNumber,
            name: name,
            defaultComment: defaultComment,
            isDefault: isDefault,
            isArchived: isArchived,
            isOwner: isOwner,
          ),
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
          ) => NewRecipientModel.sepaEur(
            label: label,
            iban: iban,
            isCorporate: isCorporate,
            firstname: firstname,
            lastname: lastname,
            corporateName: corporateName,
            isDefault: isDefault,
            isArchived: isArchived,
            isOwner: isOwner,
          ),
      speiClabeMxn:
          (label, clabe, name, isDefault, isArchived, isOwner) =>
              NewRecipientModel.speiClabeMxn(
                label: label,
                clabe: clabe,
                name: name,
                isDefault: isDefault,
                isArchived: isArchived,
                isOwner: isOwner,
              ),
      speiSmsMxn:
          (
            label,
            institutionCode,
            phone,
            name,
            isDefault,
            isArchived,
            isOwner,
          ) => NewRecipientModel.speiSmsMxn(
            label: label,
            institutionCode: institutionCode,
            phone: phone,
            name: name,
            isDefault: isDefault,
            isArchived: isArchived,
            isOwner: isOwner,
          ),
      speiCardMxn:
          (
            label,
            institutionCode,
            debitcard,
            name,
            isDefault,
            isArchived,
            isOwner,
          ) => NewRecipientModel.speiCardMxn(
            label: label,
            institutionCode: institutionCode,
            debitcard: debitcard,
            name: name,
            isDefault: isDefault,
            isArchived: isArchived,
            isOwner: isOwner,
          ),
      sinpeIbanUsd:
          (label, iban, ownerName, isDefault, isArchived, isOwner) =>
              NewRecipientModel.sinpeIbanUsd(
                label: label,
                iban: iban,
                ownerName: ownerName,
                isDefault: isDefault,
                isArchived: isArchived,
                isOwner: isOwner,
              ),
      sinpeIbanCrc:
          (label, iban, ownerName, isDefault, isArchived, isOwner) =>
              NewRecipientModel.sinpeIbanCrc(
                label: label,
                iban: iban,
                ownerName: ownerName,
                isDefault: isDefault,
                isArchived: isArchived,
                isOwner: isOwner,
              ),
      sinpeMovilCrc:
          (label, phoneNumber, ownerName, isDefault, isArchived, isOwner) =>
              NewRecipientModel.sinpeMovilCrc(
                label: label,
                phoneNumber: phoneNumber,
                ownerName: ownerName,
                isDefault: isDefault,
                isArchived: isArchived,
                isOwner: isOwner,
              ),
    );
  }

  const NewRecipientModel._();

  NewRecipient toEntity() {
    return when(
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
          ) => NewRecipient.interacEmailCad(
            label: label,
            email: email,
            name: name,
            securityQuestion: securityQuestion,
            securityAnswer: securityAnswer,
            isDefault: isDefault,
            isArchived: isArchived,
            isOwner: isOwner,
          ),
      billPaymentCad:
          (
            label,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isDefault,
            isArchived,
            isOwner,
          ) => NewRecipient.billPaymentCad(
            label: label,
            payeeName: payeeName,
            payeeCode: payeeCode,
            payeeAccountNumber: payeeAccountNumber,
            isDefault: isDefault,
            isArchived: isArchived,
            isOwner: isOwner,
          ),
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
          ) => NewRecipient.bankTransferCad(
            label: label,
            institutionNumber: institutionNumber,
            transitNumber: transitNumber,
            accountNumber: accountNumber,
            name: name,
            defaultComment: defaultComment,
            isDefault: isDefault,
            isArchived: isArchived,
            isOwner: isOwner,
          ),
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
          ) => NewRecipient.sepaEur(
            label: label,
            iban: iban,
            isCorporate: isCorporate,
            firstname: firstname,
            lastname: lastname,
            corporateName: corporateName,
            isDefault: isDefault,
            isArchived: isArchived,
            isOwner: isOwner,
          ),
      speiClabeMxn:
          (label, clabe, name, isDefault, isArchived, isOwner) =>
              NewRecipient.speiClabeMxn(
                label: label,
                clabe: clabe,
                name: name,

                isDefault: isDefault,
                isArchived: isArchived,
                isOwner: isOwner,
              ),
      speiSmsMxn:
          (
            label,
            institutionCode,
            phone,
            name,
            isDefault,
            isArchived,
            isOwner,
          ) => NewRecipient.speiSmsMxn(
            label: label,
            institutionCode: institutionCode,
            phone: phone,
            name: name,

            isDefault: isDefault,
            isArchived: isArchived,
            isOwner: isOwner,
          ),
      speiCardMxn:
          (
            label,
            institutionCode,
            debitcard,
            name,
            isDefault,
            isArchived,
            isOwner,
          ) => NewRecipient.speiCardMxn(
            label: label,
            institutionCode: institutionCode,
            debitcard: debitcard,
            name: name,

            isDefault: isDefault,
            isArchived: isArchived,
            isOwner: isOwner,
          ),
      sinpeIbanUsd:
          (label, iban, ownerName, isDefault, isArchived, isOwner) =>
              NewRecipient.sinpeIbanUsd(
                label: label,
                iban: iban,
                ownerName: ownerName,
                isDefault: isDefault,
                isArchived: isArchived,
                isOwner: isOwner,
              ),
      sinpeIbanCrc:
          (label, iban, ownerName, isDefault, isArchived, isOwner) =>
              NewRecipient.sinpeIbanCrc(
                label: label,
                iban: iban,
                ownerName: ownerName,
                isDefault: isDefault,
                isArchived: isArchived,
                isOwner: isOwner,
              ),
      sinpeMovilCrc:
          (label, phoneNumber, ownerName, isDefault, isArchived, isOwner) =>
              NewRecipient.sinpeMovilCrc(
                label: label,
                phoneNumber: phoneNumber,
                ownerName: ownerName,
                isDefault: isDefault,
                isArchived: isArchived,
                isOwner: isOwner,
              ),
    );
  }

  Map<String, dynamic> toApiParams() {
    final entity = toEntity();
    return {'element': entity.toJson()};
  }

  String get recipientTypeFiat {
    return switch (this) {
      _NewRecipientModelInteracEmailCad() => 'INTERAC_EMAIL_CAD',
      _NewRecipientModelBillPaymentCad() => 'BILL_PAYMENT_CAD',
      _NewRecipientModelBankTransferCad() => 'BANK_TRANSFER_CAD',
      _NewRecipientModelSepaEur() => 'SEPA_EUR',
      _NewRecipientModelSpeiClabeMxn() => 'SPEI_CLABE_MXN',
      _NewRecipientModelSpeiSmsMxn() => 'SPEI_SMS_MXN',
      _NewRecipientModelSpeiCardMxn() => 'SPEI_CARD_MXN',
      _NewRecipientModelSinpeIbanUsd() => 'SINPE_IBAN_USD',
      _NewRecipientModelSinpeIbanCrc() => 'SINPE_IBAN_CRC',
      _NewRecipientModelSinpeMovilCrc() => 'SINPE_MOVIL_CRC',
    };
  }
}
