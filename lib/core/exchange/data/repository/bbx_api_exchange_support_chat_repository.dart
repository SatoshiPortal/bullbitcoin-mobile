import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/mappers/bbx_api_mapper.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';

/// [ExchangeSupportChatRepository] on the shared `bbx_api` client.
class BbxApiExchangeSupportChatRepository
    implements ExchangeSupportChatRepository {
  final BbxApiDatasource _api;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final bool _isTestnet;

  BbxApiExchangeSupportChatRepository({
    required this._api,
    required this._apiKeyDatasource,
    required this._isTestnet,
  });

  @override
  Future<Result<List<SupportChatMessage>, ExchangeSupportChatFailure>>
  getMessages({int? page, int? pageSize}) => _guard(
    'Failed to load support chat messages',
    LoadMessagesFailure.new,
    () async {
      final summary = (await _api.users.getUserSummary()).unwrap();
      final messages = (await _api.messages.listMessages(
        userId: summary.userId,
        messagePayload: bbx.ListRequest<bbx.MessagesPayload>(
          paginator: bbx.Paginator(page: page ?? 1, pageSize: pageSize ?? 10),
          sortBy: bbx.SortBy.newestFirst(),
        ),
      )).unwrap();
      return messages.items.map(BbxApiMapper.supportChatMessage).toList();
    },
  );

  @override
  Future<Result<void, ExchangeSupportChatFailure>> sendMessage({
    required String text,
    List<SupportChatMessageAttachment>? attachments,
  }) => _guard(
    'Failed to send support chat message',
    SendMessageFailure.new,
    () async {
      (await _api.messages.sendSupportMessage(
        payload: bbx.PostMessagePayload(
          text: text,
          attachments: attachments
              ?.where((a) => a.fileData != null)
              .map(BbxApiMapper.outgoingAttachment)
              .toList(),
        ),
      )).unwrap();
    },
  );

  @override
  Future<Result<SupportChatMessageAttachment, ExchangeSupportChatFailure>>
  getMessageAttachment(String attachmentId) => _guard(
    'Failed to load support chat attachment',
    LoadAttachmentFailure.new,
    () async => BbxApiMapper.supportChatAttachment(
      (await _api.messages.getMessageAttachment(
        payload: bbx.GetMessageAttachmentPayload(attachmentId: attachmentId),
      )).unwrap(),
    ),
  );

  Future<Result<T, ExchangeSupportChatFailure>> _guard<T>(
    String operation,
    ExchangeSupportChatFailure Function([String?]) onFailure,
    Future<T> Function() call,
  ) async {
    final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
    if (apiKey == null) {
      log.warning('Support chat: no API key stored, user is logged out');
      return const Err(NotAuthenticatedFailure());
    }
    try {
      return Ok(await call());
    } on BbxApiException catch (e, st) {
      if (e.error.isApiKeyMissing) {
        log.warning('Support chat: not authenticated', error: e, trace: st);
        return Err(NotAuthenticatedFailure('$e'));
      }
      log.warning(operation, error: e, trace: st);
      return Err(onFailure('$e'));
    } catch (e, st) {
      log.warning(operation, error: e.runtimeType, trace: st);
      return Err(onFailure('${e.runtimeType}'));
    }
  }
}
