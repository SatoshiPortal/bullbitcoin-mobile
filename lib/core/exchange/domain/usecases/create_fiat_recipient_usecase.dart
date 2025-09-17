import 'package:bb_mobile/core/exchange/domain/entity/new_recipient.dart';
import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class CreateFiatRecipientUsecase {
  final ExchangeRecipientRepository _mainnetExchangeRecipientRepository;
  final ExchangeRecipientRepository _testnetExchangeRecipientRepository;
  final SettingsRepository _settingsRepository;

  CreateFiatRecipientUsecase({
    required ExchangeRecipientRepository mainnetExchangeRecipientRepository,
    required ExchangeRecipientRepository testnetExchangeRecipientRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeRecipientRepository = mainnetExchangeRecipientRepository,
       _testnetExchangeRecipientRepository = testnetExchangeRecipientRepository,
       _settingsRepository = settingsRepository;

  Future<Recipient> execute(NewRecipient recipient) async {
    try {
      log.fine('Creating fiat recipient: ${recipient.recipientTypeFiat}');

      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repository =
          isTestnet
              ? _testnetExchangeRecipientRepository
              : _mainnetExchangeRecipientRepository;

      final createdRecipient = await repository.createFiatRecipient(recipient);

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
