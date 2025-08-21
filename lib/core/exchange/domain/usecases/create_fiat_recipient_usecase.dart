import 'package:bb_mobile/core/exchange/domain/entity/new_recipient.dart';
import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class CreateFiatRecipientUsecase {
  final ExchangeRecipientRepository _recipientRepository;

  CreateFiatRecipientUsecase({
    required ExchangeRecipientRepository recipientRepository,
  }) : _recipientRepository = recipientRepository;

  Future<Recipient> execute(NewRecipient recipient) async {
    try {
      log.fine('Creating fiat recipient: ${recipient.recipientTypeFiat}');

      final createdRecipient = await _recipientRepository.createFiatRecipient(
        recipient,
      );

      log.fine(
        'Fiat recipient created successfully: ${createdRecipient.recipientId}',
      );

      return createdRecipient;
    } catch (e) {
      log.severe('Error in CreateFiatRecipientUsecase: $e');
      throw CreateFiatRecipientException('Failed to create fiat recipient: $e');
    }
  }
}

class CreateFiatRecipientException implements Exception {
  final String message;

  CreateFiatRecipientException(this.message);

  @override
  String toString() => '[CreateFiatRecipientUsecase]: $message';
}
