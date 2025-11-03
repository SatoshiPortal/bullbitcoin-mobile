import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/models/recipient_details_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipient_model.freezed.dart';
part 'recipient_model.g.dart';

/// MODEL: Gateway model for Recipient API serialization/deserialization
/// Maps directly to API responses
@freezed
sealed class RecipientModel with _$RecipientModel {
  const factory RecipientModel({
    required String recipientId,
    required String userId,
    required int userNbr,
    required bool isArchived,
    required String createdAt,
    required String updatedAt,
    required RecipientDetailsModel details,
  }) = _RecipientModel;

  factory RecipientModel.fromJson(Map<String, dynamic> json) =>
      _$RecipientModelFromJson(json);

  const RecipientModel._();

  /// Convert from domain entity to model
  factory RecipientModel.fromDomain(Recipient recipient) {
    return RecipientModel(
      recipientId: recipient.recipientId,
      userId: recipient.userId,
      userNbr: recipient.userNbr,
      isArchived: recipient.isArchived,
      createdAt: recipient.createdAt.toIso8601String(),
      updatedAt: recipient.updatedAt.toIso8601String(),
      details: RecipientDetailsModel.fromDomain(recipient.details),
    );
  }

  /// Convert from model to domain entity
  Recipient get toDomain {
    return Recipient.create(
      recipientId: recipientId,
      userId: userId,
      userNbr: userNbr,
      isArchived: isArchived,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      details: details.toDomain(),
    );
  }
}
