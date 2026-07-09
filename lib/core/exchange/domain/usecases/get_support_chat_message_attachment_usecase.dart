import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/errors/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class GetSupportChatMessageAttachmentUsecase {
  final ExchangeSupportChatRepository _mainnetRepository;
  final ExchangeSupportChatRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  GetSupportChatMessageAttachmentUsecase({
    required this._mainnetRepository,
    required this._testnetRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<SupportChatMessageAttachment, ExchangeSupportChatFailure>>
  execute(String attachmentId) async {
    final ExchangeSupportChatRepository repository;
    try {
      final settings = await _settingsRepository.fetch();
      repository = settings.environment.isTestnet
          ? _testnetRepository
          : _mainnetRepository;
    } catch (e, st) {
      log.warning(
        'Failed to resolve support chat network',
        error: e,
        trace: st,
      );
      return Err(LoadAttachmentFailure('$e'));
    }

    return repository.getMessageAttachment(attachmentId);
  }
}
