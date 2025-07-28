import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipient.freezed.dart';
part 'recipient.g.dart';

@freezed
sealed class Recipient with _$Recipient {
  const factory Recipient({
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
  }) = _Recipient;

  factory Recipient.fromJson(Map<String, dynamic> json) =>
      _$RecipientFromJson(json);
}
