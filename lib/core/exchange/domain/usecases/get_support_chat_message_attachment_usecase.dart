import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class GetSupportChatMessageAttachmentUsecase {
  final ExchangeSupportChatRepository _mainnetRepository;
  final ExchangeSupportChatRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  GetSupportChatMessageAttachmentUsecase({
    required ExchangeSupportChatRepository mainnetRepository,
    required ExchangeSupportChatRepository testnetRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository,
       _settingsRepository = settingsRepository;

  Future<SupportChatMessageAttachment> execute(String attachmentId) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet ? _testnetRepository : _mainnetRepository;

      return await repo.getMessageAttachment(attachmentId);
    } catch (e) {
      throw GetSupportChatMessageAttachmentException('$e');
    }
  }
}

class GetSupportChatMessageAttachmentException extends BullException {
  GetSupportChatMessageAttachmentException(super.message);
}

