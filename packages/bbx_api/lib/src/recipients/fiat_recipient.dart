import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
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

  /// Throws a [BbxApiFormatException] naming the first invalid field.
  factory FiatRecipient.fromJson(Map<String, dynamic> json) {
    String? text(String field) => read<String?>(json[field], field);
    bool? flag(String field) => read<bool?>(json[field], field);
    return FiatRecipient(
      recipientId: read<String>(json['recipientId'], 'recipientId'),
      userId: read<String>(json['userId'], 'userId'),
      userNbr: read<int>(json['userNbr'], 'userNbr'),
      isArchived: read<bool>(json['isArchived'], 'isArchived'),
      createdAt: read<String>(json['createdAt'], 'createdAt'),
      updatedAt: read<String>(json['updatedAt'], 'updatedAt'),
      recipientTypeFiat: read<String>(
        json['recipientTypeFiat'],
        'recipientTypeFiat',
      ),
      label: text('label'),
      isOwner: flag('isOwner'),
      isDefault: flag('isDefault'),
      email: text('email'),
      name: text('name'),
      securityQuestion: text('securityQuestion'),
      securityAnswer: text('securityAnswer'),
      payeeName: text('payeeName'),
      payeeCode: text('payeeCode'),
      payeeAccountNumber: text('payeeAccountNumber'),
      institutionNumber: text('institutionNumber'),
      transitNumber: text('transitNumber'),
      accountNumber: text('accountNumber'),
      defaultComment: text('defaultComment'),
      iban: text('iban'),
      isCorporate: flag('isCorporate'),
      firstname: text('firstname'),
      lastname: text('lastname'),
      corporateName: text('corporateName'),
      virtualPayeeStatus: text('virtualPayeeStatus'),
      clabe: text('clabe'),
      institutionCode: text('institutionCode'),
      phone: text('phone'),
      debitcard: text('debitcard'),
      ownerName: text('ownerName'),
      phoneNumber: text('phoneNumber'),
      claveUniform: text('claveUniform'),
      bankCode: text('bankCode'),
      accountType: text('accountType'),
      bankAccount: text('bankAccount'),
      bankName: text('bankName'),
      documentId: text('documentId'),
      documentType: text('documentType'),
    );
  }
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
