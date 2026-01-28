import 'package:freezed_annotation/freezed_annotation.dart';

part 'virtual_iban_recipient_model.freezed.dart';
part 'virtual_iban_recipient_model.g.dart';

/// Model for Virtual IBAN recipient API responses.
@freezed
sealed class VirtualIbanRecipientModel with _$VirtualIbanRecipientModel {
  const factory VirtualIbanRecipientModel({
    required String recipientId,
    String? iban,
    String? bicCode,
    String? bankAddress,
    String? ibanCountry,
    String? frAccountId,
    String? frUserId,
    String? frPayeeId,
    @Default(false) bool isOwner,
    String? createdAt,
    String? updatedAt,
    String? recipientType,
  }) = _VirtualIbanRecipientModel;

  factory VirtualIbanRecipientModel.fromJson(Map<String, dynamic> json) =>
      _$VirtualIbanRecipientModelFromJson(json);
}

