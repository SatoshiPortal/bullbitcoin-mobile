import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/public/recipient_view_model.dart';

extension RecipientViewModelMapper on RecipientDto {
  RecipientViewModel toViewModel() {
    return RecipientViewModel(
      id: recipientId,
      type: recipientType,
      name: details.name,
      firstname: details.firstname,
      lastname: details.lastname,
      email: details.email,
      isCorporate: details.isCorporate,
      corporateName: details.corporateName,
      ownerName: details.ownerName,
      label: details.label,
      payeeName: details.payeeName,
      payeeCode: details.payeeCode,
      payeeAccountNumber: details.payeeAccountNumber,
      institutionNumber: details.institutionNumber,
      transitNumber: details.transitNumber,
      accountNumber: details.accountNumber,
      iban: details.iban,
      clabe: details.clabe,
      phoneNumber: details.phoneNumber,
      debitcard: details.debitcard,
      isOwner: isOwner,
      bankAccount: details.bankAccount ?? details.claveUniform,
    );
  }
}
