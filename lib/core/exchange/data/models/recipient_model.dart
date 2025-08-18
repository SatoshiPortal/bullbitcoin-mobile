import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipient_model.freezed.dart';
part 'recipient_model.g.dart';

@freezed
sealed class RecipientModel with _$RecipientModel {
  const factory RecipientModel({
    required String recipientId,
    required String userId,
    required int userNbr,
    required bool isOwner,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? label,
    String? recipientType,
    String? firstname,
    String? lastname,
    String? name,
    String? iban,
    String? email,
    String? securityQuestion,
    String? securityAnswer,
    String? institutionNumber,
    String? transitNumber,
    String? accountNumber,
    String? billerPayeeCode,
    String? billerPayeeName,
    String? billerPayeeAccountNumber,
    String? address,
    bool? isDefault,
    String? clabe,
    String? phone,
    String? debitCard,
    String? institutionCode,
    bool? isCorporate,
    String? corporateName,
    // New fields from API response
    String? ownerName,
    String? currency,
    String? recipientTypeFiat,
    String? phoneNumber,
    String? defaultComment,
    String? payeeName,
    String? payeeCode,
    String? payeeAccountNumber,
    // Additional fields from API
    String? debitcard,
  }) = _RecipientModel;

  factory RecipientModel.fromJson(Map<String, dynamic> json) =>
      _$RecipientModelFromJson(json);

  const RecipientModel._();

  Recipient toEntity() {
    if (recipientTypeFiat != null) {
      final recipientType = WithdrawRecipientType.fromValue(recipientTypeFiat!);
      // Use the appropriate factory constructor based on recipientTypeFiat
      switch (recipientType) {
        case WithdrawRecipientType.interacEmailCad:
          return Recipient.interacEmailCad(
            recipientId: recipientId,
            userId: userId,
            userNbr: userNbr,
            isOwner: isOwner,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            label: label,
            name: name,
            email: email,
            securityQuestion: securityQuestion,
            securityAnswer: securityAnswer,
            isDefault: isDefault,
            defaultComment: defaultComment,
            firstname: firstname,
            lastname: lastname,
            isCorporate: isCorporate,
            corporateName: corporateName,
          );
        case WithdrawRecipientType.billPaymentCad:
          return Recipient.billPaymentCad(
            recipientId: recipientId,
            userId: userId,
            userNbr: userNbr,
            isOwner: isOwner,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            label: label,
            isDefault: isDefault,
            payeeName: payeeName,
            payeeCode: payeeCode,
            payeeAccountNumber: payeeAccountNumber,
            isCorporate: isCorporate,
            corporateName: corporateName,
          );
        case WithdrawRecipientType.bankTransferCad:
          return Recipient.bankTransferCad(
            recipientId: recipientId,
            userId: userId,
            userNbr: userNbr,
            isOwner: isOwner,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            label: label,
            firstname: firstname,
            lastname: lastname,
            name: name,
            institutionNumber: institutionNumber,
            transitNumber: transitNumber,
            accountNumber: accountNumber,
            isDefault: isDefault,
            ownerName: ownerName,
            currency: currency,
            defaultComment: defaultComment,
            payeeName: payeeName,
            payeeCode: payeeCode,
            payeeAccountNumber: payeeAccountNumber,
            isCorporate: isCorporate,
            corporateName: corporateName,
          );
        case WithdrawRecipientType.sepaEur:
          return Recipient.sepaEur(
            recipientId: recipientId,
            userId: userId,
            userNbr: userNbr,
            isOwner: isOwner,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            label: label,
            firstname: firstname,
            lastname: lastname,
            name: name,
            iban: iban,
            address: address,
            isDefault: isDefault,
            ownerName: ownerName,
            currency: currency,
            defaultComment: defaultComment,
            payeeName: payeeName,
            payeeCode: payeeCode,
            payeeAccountNumber: payeeAccountNumber,
            isCorporate: isCorporate,
            corporateName: corporateName,
          );
        case WithdrawRecipientType.speiClabeMxn:
          return Recipient.speiClabeMxn(
            recipientId: recipientId,
            userId: userId,
            userNbr: userNbr,
            isOwner: isOwner,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            label: label,
            firstname: firstname,
            lastname: lastname,
            name: name,
            clabe: clabe,
            institutionCode: institutionCode,
            isDefault: isDefault,
            ownerName: ownerName,
            currency: currency,
            defaultComment: defaultComment,
            payeeName: payeeName,
            payeeCode: payeeCode,
            payeeAccountNumber: payeeAccountNumber,
            isCorporate: isCorporate,
            corporateName: corporateName,
          );
        case WithdrawRecipientType.speiSmsMxn:
          return Recipient.speiSmsMxn(
            recipientId: recipientId,
            userId: userId,
            userNbr: userNbr,
            isOwner: isOwner,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            label: label,
            firstname: firstname,
            lastname: lastname,
            name: name,
            phone: phone,
            phoneNumber: phoneNumber,
            institutionCode: institutionCode,
            isDefault: isDefault,
            ownerName: ownerName,
            currency: currency,
            defaultComment: defaultComment,
            isCorporate: isCorporate,
            corporateName: corporateName,
          );
        case WithdrawRecipientType.speiCardMxn:
          return Recipient.speiCardMxn(
            recipientId: recipientId,
            userId: userId,
            userNbr: userNbr,
            isOwner: isOwner,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            label: label,
            firstname: firstname,
            lastname: lastname,
            name: name,
            debitCard: debitCard ?? debitcard, // Handle both fields from API
            institutionCode: institutionCode,
            isDefault: isDefault,
            ownerName: ownerName,
            currency: currency,
            defaultComment: defaultComment,
            isCorporate: isCorporate,
            corporateName: corporateName,
          );
        case WithdrawRecipientType.sinpeIbanUsd:
          return Recipient.sinpeIbanUsd(
            recipientId: recipientId,
            userId: userId,
            userNbr: userNbr,
            isOwner: isOwner,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            label: label,
            isDefault: isDefault,
            iban: iban,
            ownerName: ownerName,
            currency: currency,
            isCorporate: isCorporate,
            corporateName: corporateName,
          );
        case WithdrawRecipientType.sinpeIbanCrc:
          return Recipient.sinpeIbanCrc(
            recipientId: recipientId,
            userId: userId,
            userNbr: userNbr,
            isOwner: isOwner,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            label: label,
            isDefault: isDefault,
            iban: iban,
            ownerName: ownerName,
            currency: currency,
            isCorporate: isCorporate,
            corporateName: corporateName,
          );
        case WithdrawRecipientType.sinpeMovilCrc:
          return Recipient.sinpeMovilCrc(
            recipientId: recipientId,
            userId: userId,
            userNbr: userNbr,
            isOwner: isOwner,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            label: label,
            isDefault: isDefault,
            phoneNumber: phoneNumber,
            ownerName: ownerName,
            currency: currency,
            defaultComment: defaultComment,
            isCorporate: isCorporate,
            corporateName: corporateName,
          );
      }
    }

    // Fallback to a default constructor if recipientTypeFiat is null
    // This maintains backward compatibility
    throw Exception(
      'recipientTypeFiat is required to create a Recipient entity',
    );
  }
}
