import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class GetSupportChatMessagesUsecase {
  final ExchangeSupportChatRepository _mainnetRepository;
  final ExchangeSupportChatRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  GetSupportChatMessagesUsecase({
    required ExchangeSupportChatRepository mainnetRepository,
    required ExchangeSupportChatRepository testnetRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository,
       _settingsRepository = settingsRepository;

  Future<List<SupportChatMessage>> execute({
    int? page,
    int? pageSize,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet ? _testnetRepository : _mainnetRepository;

      return await repo.getMessages(
        page: page,
        pageSize: pageSize,
      );
    } catch (e) {
      throw GetSupportChatMessagesException('$e');
    }
  }
}

class GetSupportChatMessagesException extends BullException {
  GetSupportChatMessagesException(super.message);
}

