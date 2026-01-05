import 'package:bb_mobile/core/exchange/data/models/virtual_iban_recipient_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/virtual_iban_recipient.dart';

/// Mapper for converting between VirtualIbanRecipientModel and VirtualIbanRecipient entity.
class VirtualIbanRecipientMapper {
  static VirtualIbanRecipient fromModelToEntity(
    VirtualIbanRecipientModel model,
  ) {
    return VirtualIbanRecipient(
      recipientId: model.recipientId,
      iban: model.iban,
      bicCode: model.bicCode,
      bankAddress: model.bankAddress,
      ibanCountry: model.ibanCountry,
      frAccountId: model.frAccountId,
      frUserId: model.frUserId,
      frPayeeId: model.frPayeeId,
      isOwner: model.isOwner,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    );
  }
}


