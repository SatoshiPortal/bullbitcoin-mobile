import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:meta/meta.dart';

@immutable
class Recipient {
  // identity => entity
  final String recipientId;
  final String userId;
  final int userNbr;
  // lifecycle/state belongs on the entity
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// All user-supplied attributes live inside the VO.
  final RecipientDetails details;

  const Recipient._({
    required this.recipientId,
    required this.userId,
    required this.userNbr,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    required this.details,
  });

  factory Recipient.create({
    required String recipientId,
    required String userId,
    required int userNbr,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
    required RecipientDetails details,
  }) {
    if (recipientId.trim().isEmpty) {
      throw ArgumentError('Recipient ID cannot be empty');
    }
    if (userId.trim().isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }
    if (userNbr < 0) {
      throw ArgumentError('User number cannot be negative');
    }

    return Recipient._(
      recipientId: recipientId.trim(),
      userId: userId.trim(),
      userNbr: userNbr,
      isArchived: isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt,
      details: details,
    );
  }

  RecipientType get type => details.type;

  String? get label => details.label;
  bool get isDefault => details.isDefault;
  bool? get isOwner => details.isOwner;
}
