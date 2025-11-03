import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:meta/meta.dart';

@immutable
class RecipientDto {
  // ── Entity (identity + lifecycle)
  final String recipientId;
  final String userId;
  final int userNbr;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── All user-supplied/variant-specific data lives here
  final RecipientDetailsDto details;

  const RecipientDto({
    required this.recipientId,
    required this.userId,
    required this.userNbr,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    required this.details,
  });

  // Convenience getters (derived, not stored twice)
  String get recipientType => details.recipientType; // e.g. 'SEPA_EUR'
  bool get isOwner => details.isOwner;
  bool? get isDefault => details.isDefault;
  String? get label => details.label;

  // ─────────────────────────────────────────────
  // Domain → DTO
  // ─────────────────────────────────────────────
  factory RecipientDto.fromDomain(Recipient entity) {
    return RecipientDto(
      recipientId: entity.recipientId,
      userId: entity.userId,
      userNbr: entity.userNbr,
      isArchived: entity.isArchived,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      details: RecipientDetailsDto.fromDomain(entity.details),
    );
  }

  // ─────────────────────────────────────────────
  // DTO → Domain
  // ─────────────────────────────────────────────
  Recipient toDomain() {
    final RecipientDetails vo = details.toDomain();

    return Recipient.create(
      recipientId: recipientId,
      userId: userId,
      userNbr: userNbr,
      isArchived: isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt,
      details: vo,
    );
  }
}
