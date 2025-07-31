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
    List<String>? paymentProcessors,
    required String recipientType,
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
  }) = _RecipientModel;

  factory RecipientModel.fromJson(Map<String, dynamic> json) =>
      _$RecipientModelFromJson(json);

  const RecipientModel._();

  Recipient toEntity() {
    return Recipient(
      recipientId: recipientId,
      userId: userId,
      userNbr: userNbr,
      isOwner: isOwner,
      isArchived: isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt,
      label: label,
      paymentProcessors: paymentProcessors,
      recipientType: recipientType,
      firstname: firstname,
      lastname: lastname,
      name: name,
      iban: iban,
      email: email,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      institutionNumber: institutionNumber,
      transitNumber: transitNumber,
      accountNumber: accountNumber,
      billerPayeeCode: billerPayeeCode,
      billerPayeeName: billerPayeeName,
      billerPayeeAccountNumber: billerPayeeAccountNumber,
      address: address,
      isDefault: isDefault,
      clabe: clabe,
      phone: phone,
      debitCard: debitCard,
      institutionCode: institutionCode,
      isCorporate: isCorporate,
      corporateName: corporateName,
    );
  }
}
