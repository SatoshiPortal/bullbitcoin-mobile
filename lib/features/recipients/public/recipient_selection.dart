import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';

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

  bool get requiresInteracSecurityDetails =>
      type == RecipientType.interacEmailCad;

  @override
  String toString() => 'RecipientSelection(id: $id, type: $type)';
}
