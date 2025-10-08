import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class ListRecipientsUsecase {
  final ExchangeRecipientRepository _mainnetExchangeRecipientRepository;
  final ExchangeRecipientRepository _testnetExchangeRecipientRepository;
  final SettingsRepository _settingsRepository;

  ListRecipientsUsecase({
    required ExchangeRecipientRepository mainnetExchangeRecipientRepository,
    required ExchangeRecipientRepository testnetExchangeRecipientRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeRecipientRepository = mainnetExchangeRecipientRepository,
       _testnetExchangeRecipientRepository = testnetExchangeRecipientRepository,
       _settingsRepository = settingsRepository;

  Future<List<Recipient>> execute({bool fiatOnly = true}) async {
    try {
      log.info(
        'ListRecipientsUsecase: Starting to fetch recipients (fiatOnly: $fiatOnly)',
      );
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeRecipientRepository
              : _mainnetExchangeRecipientRepository;
      final recipients = await repo.listRecipients(fiatOnly: fiatOnly);
      log.info(
        'ListRecipientsUsecase: Successfully fetched ${recipients.length} recipients',
      );
      return recipients;
    } catch (e) {
      log.severe('Error in ListRecipientsUsecase: $e');
      throw ListRecipientsException('$e');
    }
  }
}

class ListRecipientsException extends BullException {
  ListRecipientsException(super.message);
}
