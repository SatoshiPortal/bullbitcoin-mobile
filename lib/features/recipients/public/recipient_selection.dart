import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';

/// Recipient data published for cross-feature selection flows.
final class RecipientSelection {
  const RecipientSelection({
    required this.id,
    required this.type,
    this.displayName,
    this.email,
    this.securityQuestion,
    this.securityAnswer,
    this.payeeName,
    this.payeeCode,
    this.payeeAccountNumber,
    this.institutionNumber,
    this.transitNumber,
    this.accountNumber,
    this.iban,
    this.clabe,
    this.phoneNumber,
    this.debitcard,
    this.bankAccount,
    this.isVirtualPayeeActive = false,
  });

  final String id;
  final RecipientType type;
  final String? displayName;
  final String? email;
  final String? securityQuestion;
  final String? securityAnswer;
  final String? payeeName;
  final String? payeeCode;
  final String? payeeAccountNumber;
  final String? institutionNumber;
  final String? transitNumber;
  final String? accountNumber;
  final String? iban;
  final String? clabe;
  final String? phoneNumber;
  final String? debitcard;
  final String? bankAccount;
  final bool isVirtualPayeeActive;

  bool get requiresInteracSecurityDetails =>
      type == RecipientType.interacEmailCad;

  /// A Confidential SEPA payout needs the recipient's virtual payee to be
  /// active.
  bool get requiresVirtualPayeeActivation =>
      type == RecipientType.confidentialSepaEur && !isVirtualPayeeActive;

  /// The same account, paid through regular SEPA.
  RecipientSelection asRegularSepa() => RecipientSelection(
    id: id,
    type: type == RecipientType.confidentialSepaEur
        ? RecipientType.sepaEur
        : type,
    displayName: displayName,
    email: email,
    securityQuestion: securityQuestion,
    securityAnswer: securityAnswer,
    payeeName: payeeName,
    payeeCode: payeeCode,
    payeeAccountNumber: payeeAccountNumber,
    institutionNumber: institutionNumber,
    transitNumber: transitNumber,
    accountNumber: accountNumber,
    iban: iban,
    clabe: clabe,
    phoneNumber: phoneNumber,
    debitcard: debitcard,
    bankAccount: bankAccount,
  );

  RecipientSelection asVirtualPayeeActive() => RecipientSelection(
    id: id,
    type: type,
    displayName: displayName,
    email: email,
    securityQuestion: securityQuestion,
    securityAnswer: securityAnswer,
    payeeName: payeeName,
    payeeCode: payeeCode,
    payeeAccountNumber: payeeAccountNumber,
    institutionNumber: institutionNumber,
    transitNumber: transitNumber,
    accountNumber: accountNumber,
    iban: iban,
    clabe: clabe,
    phoneNumber: phoneNumber,
    debitcard: debitcard,
    bankAccount: bankAccount,
    isVirtualPayeeActive: true,
  );

  @override
  String toString() => 'RecipientSelection(id: $id, type: $type)';
}
