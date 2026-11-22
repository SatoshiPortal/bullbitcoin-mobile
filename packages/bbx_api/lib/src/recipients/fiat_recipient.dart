import 'package:meta/meta.dart';

/// A fiat recipient as `api-recipients` returns it: the identity fields and
/// the flat details of every recipient type, unparsed. Which detail fields
/// are set depends on [recipientTypeFiat].
@immutable
class FiatRecipient {
  final String recipientId;
  final String userId;
  final int userNbr;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;

  /// The type discriminator, for example `INTERAC_EMAIL_CAD`.
  final String recipientTypeFiat;
  final String? label;
  final bool? isOwner;
  final bool? isDefault;
  final String? email;
  final String? name;
  final String? securityQuestion;
  final String? securityAnswer;
  final String? payeeName;
  final String? payeeCode;
  final String? payeeAccountNumber;
  final String? institutionNumber;
  final String? transitNumber;
  final String? accountNumber;
  final String? defaultComment;
  final String? iban;
  final bool? isCorporate;
  final String? firstname;
  final String? lastname;
  final String? corporateName;

  /// Absent until a SEPA recipient has a virtual payee.
  final String? virtualPayeeStatus;
  final String? clabe;
  final String? institutionCode;
  final String? phone;
  final String? debitcard;
  final String? ownerName;
  final String? phoneNumber;
  final String? claveUniform;
  final String? bankCode;
  final String? accountType;
  final String? bankAccount;
  final String? bankName;
  final String? documentId;
  final String? documentType;

  const FiatRecipient({
    required this.recipientId,
    required this.userId,
    required this.userNbr,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    required this.recipientTypeFiat,
    this.label,
    this.isOwner,
    this.isDefault,
    this.email,
    this.name,
    this.securityQuestion,
    this.securityAnswer,
    this.payeeName,
    this.payeeCode,
    this.payeeAccountNumber,
    this.institutionNumber,
    this.transitNumber,
    this.accountNumber,
    this.defaultComment,
    this.iban,
    this.isCorporate,
    this.firstname,
    this.lastname,
    this.corporateName,
    this.virtualPayeeStatus,
    this.clabe,
    this.institutionCode,
    this.phone,
    this.debitcard,
    this.ownerName,
    this.phoneNumber,
    this.claveUniform,
    this.bankCode,
    this.accountType,
    this.bankAccount,
    this.bankName,
    this.documentId,
    this.documentType,
  });
}

/// One page of fiat recipients.
///
/// An element that is not a valid [FiatRecipient] is left out of
/// [recipients] and counted in [skippedElements], so that one recipient of a
/// type this client cannot read does not hide the others.
@immutable
class FiatRecipientPage {
  /// The number of recipients over all pages, as sent.
  final num totalElements;
  final List<FiatRecipient> recipients;
  final int skippedElements;

  const FiatRecipientPage({
    required this.totalElements,
    required this.recipients,
    this.skippedElements = 0,
  });
}
