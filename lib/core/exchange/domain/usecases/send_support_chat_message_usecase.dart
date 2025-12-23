import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class SendSupportChatMessageUsecase {
  final ExchangeSupportChatRepository _mainnetRepository;
  final ExchangeSupportChatRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  SendSupportChatMessageUsecase({
    required ExchangeSupportChatRepository mainnetRepository,
    required ExchangeSupportChatRepository testnetRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository,
       _settingsRepository = settingsRepository;

  Future<void> execute({
    required String text,
    List<SupportChatMessageAttachment>? attachments,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet ? _testnetRepository : _mainnetRepository;

      await repo.sendMessage(
        text: text,
        attachments: attachments,
      );
    } catch (e) {
      throw SendSupportChatMessageException('$e');
    }
  }
}

class SendSupportChatMessageException extends BullException {
  SendSupportChatMessageException(super.message);
}

