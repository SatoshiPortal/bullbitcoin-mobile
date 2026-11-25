import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/exchange.dart';

/// A saved recipient of [type] with valid details, as the recipient screens
/// show it.
RecipientViewModel recipientFixture(
  String id,
  RecipientType type, {
  bool? isOwner,
  String? label,
  String? name,
  String firstname = 'Satoshi',
  String lastname = 'Nakamoto',
  String iban = 'FR7616958000016918327146718',
  String email = 'satoshi@example.com',
  String? securityQuestion,
  String? securityAnswer,
  String phoneNumber = '88888888',
  bool virtualPayeeActive = false,
}) => RecipientViewModel(
  Recipient.create(
    recipientId: id,
    userId: 'user-1',
    userNbr: 1,
    isArchived: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    details: RecipientDetailsInput(
      recipientType: type,
      label: label,
      isOwner: isOwner,
      email: email,
      name: name ?? '$firstname $lastname',
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      payeeName: name ?? 'Hydro',
      payeeCode: '1234',
      payeeAccountNumber: '55667788',
      institutionNumber: '001',
      transitNumber: '12345',
      accountNumber: '1234567',
      iban: iban,
      isCorporate: false,
      firstname: firstname,
      lastname: lastname,
      virtualPayeeStatus: virtualPayeeActive
          ? SepaVirtualPayeeStatus.active
          : SepaVirtualPayeeStatus.absent,
      clabe: '002010077777777771',
      institutionCode: '40002',
      phone: '5512345678',
      debitcard: '4111111111111111',
      ownerName: name ?? '$firstname $lastname',
      phoneNumber: phoneNumber,
      claveUniform: '0170099220000067797171',
      bankCode: '1007',
      accountType: 'SAVINGS',
      bankAccount: '123456',
      documentId: '123456',
      documentType: 'CC',
    ).toDomain(),
  ),
);
