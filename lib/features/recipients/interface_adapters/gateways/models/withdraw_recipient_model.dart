import 'package:bb_mobile/features/recipients/domain/entities/withdraw_recipient.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/withdraw_recipient_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'withdraw_recipient_model.freezed.dart';
part 'withdraw_recipient_model.g.dart';

/// MODEL: Gateway model for API serialization/deserialization
/// Models are flat data containers that map directly to API responses
/// They use freezed for immutability and JSON serialization
@freezed
class WithdrawRecipientModel with _$WithdrawRecipientModel {
  const factory WithdrawRecipientModel({
    required String recipientId,
    required String userId,
    required int userNbr,
    required bool isOwner,
    required bool isArchived,
    required String createdAt,
    required String updatedAt,
    String? label,
    String? recipientTypeFiat,
    String? ownerName,
    String? email,
    String? iban,
    String? phoneNumber,
    String? institutionNumber,
    String? transitNumber,
    String? accountNumber,
    String? payeeName,
    String? payeeCode,
    String? payeeAccountNumber,
    String? clabe,
    String? institutionCode,
    String? debitCard,
    bool? isDefault,
    bool? isCorporate,
    String? corporateName,
  }) = _WithdrawRecipientModel;

  factory WithdrawRecipientModel.fromJson(Map<String, dynamic> json) =>
      _$WithdrawRecipientModelFromJson(json);

  const WithdrawRecipientModel._();

  /// Convert from model to domain entity
  WithdrawRecipient toEntity() {
    if (recipientTypeFiat == null) {
      throw Exception('recipientTypeFiat is required');
    }

    final type = WithdrawRecipientType.fromValue(recipientTypeFiat!);
    final createdAtDateTime = DateTime.parse(createdAt);
    final updatedAtDateTime = DateTime.parse(updatedAt);

    // Determine the display details based on type
    String? displayDetails;
    switch (type) {
      case WithdrawRecipientType.interacEmailCad:
        displayDetails = email;
        break;
      case WithdrawRecipientType.billPaymentCad:
        displayDetails = payeeAccountNumber;
        break;
      case WithdrawRecipientType.bankTransferCad:
        displayDetails = accountNumber;
        break;
      case WithdrawRecipientType.sepaEur:
      case WithdrawRecipientType.sinpeIbanUsd:
      case WithdrawRecipientType.sinpeIbanCrc:
        displayDetails = iban;
        break;
      case WithdrawRecipientType.speiClabeMxn:
        displayDetails = clabe;
        break;
      case WithdrawRecipientType.speiSmsMxn:
      case WithdrawRecipientType.sinpeMovilCrc:
        displayDetails = phoneNumber;
        break;
      case WithdrawRecipientType.speiCardMxn:
        displayDetails = debitCard;
        break;
    }

    return WithdrawRecipient.existing(
      recipientId: recipientId,
      recipientType: type,
      userId: userId,
      userNbr: userNbr,
      isOwner: isOwner,
      isArchived: isArchived,
      createdAt: createdAtDateTime,
      updatedAt: updatedAtDateTime,
      label: label,
      ownerName: ownerName,
      displayDetails: displayDetails,
      isDefault: isDefault ?? false,
      isCorporate: isCorporate,
      corporateName: corporateName,
    );
  }
}
