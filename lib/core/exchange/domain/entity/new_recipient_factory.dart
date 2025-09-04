import 'package:bb_mobile/core/exchange/domain/entity/new_recipient.dart';
import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';

class NewRecipientFactory {
  static NewRecipient fromFormData(
    WithdrawRecipientType type,
    Map<String, dynamic> formData,
  ) {
    final label = formData['label'] as String?;
    final isDefault = formData['isDefault'] as bool? ?? false;
    final isArchived = formData['isArchived'] as bool? ?? false;
    final isOwner = (formData['isOwner'] as String?) == 'true';

    switch (type) {
      case WithdrawRecipientType.interacEmailCad:
        return NewRecipient.interacEmailCad(
          label: label,
          email: formData['email'] as String,
          name: formData['name'] as String,
          securityQuestion: formData['securityQuestion'] as String,
          securityAnswer: formData['securityAnswer'] as String,
          isDefault: isDefault,
          isArchived: isArchived,
          isOwner: isOwner,
        );

      case WithdrawRecipientType.billPaymentCad:
        return NewRecipient.billPaymentCad(
          label: label,
          payeeName: formData['payeeName'] as String,
          payeeCode: formData['payeeCode'] as String,
          payeeAccountNumber: formData['payeeAccountNumber'] as String,
          isDefault: isDefault,
          isArchived: isArchived,
          isOwner: isOwner,
        );

      case WithdrawRecipientType.bankTransferCad:
        return NewRecipient.bankTransferCad(
          label: label,
          institutionNumber: formData['institutionNumber'] as String,
          transitNumber: formData['transitNumber'] as String,
          accountNumber: formData['accountNumber'] as String,
          name: formData['name'] as String,
          defaultComment: formData['defaultComment'] as String?,
          isDefault: isDefault,
          isArchived: isArchived,
          isOwner: isOwner,
        );

      case WithdrawRecipientType.sepaEur:
        final isCorporate = (formData['isCorporate'] as String?) == 'true';
        return NewRecipient.sepaEur(
          label: label,
          iban: formData['iban'] as String,
          isCorporate: isCorporate,
          firstname: isCorporate ? null : formData['firstname'] as String?,
          lastname: isCorporate ? null : formData['lastname'] as String?,
          corporateName:
              isCorporate ? formData['corporateName'] as String? : null,
          isDefault: isDefault,
          isArchived: isArchived,
          isOwner: isOwner,
        );

      case WithdrawRecipientType.speiClabeMxn:
        return NewRecipient.speiClabeMxn(
          label: label,
          clabe: formData['clabe'] as String,
          name: formData['name'] as String,
          isDefault: isDefault,
          isArchived: isArchived,
          isOwner: isOwner,
        );

      case WithdrawRecipientType.speiSmsMxn:
        return NewRecipient.speiSmsMxn(
          label: label,
          institutionCode: formData['institutionCode'] as String,
          phone: formData['phoneNumber'] as String,
          name: formData['name'] as String,
          isDefault: isDefault,
          isArchived: isArchived,
          isOwner: isOwner,
        );

      case WithdrawRecipientType.speiCardMxn:
        return NewRecipient.speiCardMxn(
          label: label,
          institutionCode: formData['institutionCode'] as String,
          debitcard: formData['debitCard'] as String,
          name: formData['name'] as String,
          isDefault: isDefault,
          isArchived: isArchived,
          isOwner: isOwner,
        );

      case WithdrawRecipientType.sinpeIbanUsd:
        return NewRecipient.sinpeIbanUsd(
          label: label,
          iban: formData['iban'] as String,
          ownerName: formData['ownerName'] as String,
          isDefault: isDefault,
          isArchived: isArchived,
          isOwner: isOwner,
        );

      case WithdrawRecipientType.sinpeIbanCrc:
        return NewRecipient.sinpeIbanCrc(
          label: label,
          iban: formData['iban'] as String,
          ownerName: formData['ownerName'] as String,
          isDefault: isDefault,
          isArchived: isArchived,
          isOwner: isOwner,
        );

      case WithdrawRecipientType.sinpeMovilCrc:
        return NewRecipient.sinpeMovilCrc(
          label: label,
          phoneNumber: formData['phoneNumber'] as String,
          ownerName: formData['ownerName'] as String,
          isDefault: isDefault,
          isArchived: isArchived,
          isOwner: isOwner,
        );
    }
  }
}
