import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_support_chat_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/support_chat_message_attachment_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';

class ExchangeSupportChatRepositoryImpl
    implements ExchangeSupportChatRepository {
  final ExchangeSupportChatDatasource _datasource;
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;

  ExchangeSupportChatRepositoryImpl({
    required this._datasource,
    required this._bullbitcoinApiDatasource,
  });

  @override
  Future<Result<List<SupportChatMessage>, ExchangeSupportChatFailure>>
  getMessages({int? page, int? pageSize}) async {
    try {
      final userSummaryModel = await _bullbitcoinApiDatasource.getUserSummary();
      final userId = userSummaryModel?.userId;
      if (userId == null) {
        // No usable identity behind the key: the session is not good enough to read the thread, which is an auth problem rather than a transport one.
        log.warning('Support chat: user summary carries no user id');
        return const Err(NotAuthenticatedFailure());
      }

      final messageModels = await _datasource.listMessages(
        userId: userId,
        page: page,
        pageSize: pageSize,
      );

      return Ok(messageModels.map((model) => model.toEntity()).toList());
    } on ApiKeyException catch (e, st) {
      log.warning(
        'Support chat: not authenticated',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(NotAuthenticatedFailure());
    } catch (e, st) {
      if (exchangeAuthenticationException(e)?.isUnauthenticated ?? false) {
        return const Err(NotAuthenticatedFailure());
      }
      log.warning(
        'Failed to load support chat messages',
        error: e.runtimeType,
        trace: st,
      );
      return Err(LoadMessagesFailure('Load messages failed: ${e.runtimeType}'));
    }
  }

  @override
  Future<Result<void, ExchangeSupportChatFailure>> sendMessage({
    required String text,
    List<SupportChatMessageAttachment>? attachments,
  }) async {
    try {
      final attachmentModels = attachments
          ?.map(
            (attachment) => SupportChatMessageAttachmentModel(
              attachmentId: attachment.attachmentId,
              fileName: attachment.fileName,
              fileType: attachment.fileType,
              fileSize: attachment.fileSize,
              fileData: attachment.fileData,
              messageId: attachment.messageId,
              createdAt: attachment.createdAt,
            ),
          )
          .toList();

      await _datasource.sendMessage(text: text, attachments: attachmentModels);
      return const Ok(null);
    } on ApiKeyException catch (e, st) {
      log.warning(
        'Support chat: not authenticated',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(NotAuthenticatedFailure());
    } catch (e, st) {
      if (exchangeAuthenticationException(e)?.isUnauthenticated ?? false) {
        return const Err(NotAuthenticatedFailure());
      }
      log.warning(
        'Failed to send support chat message',
        error: e.runtimeType,
        trace: st,
      );
      return Err(SendMessageFailure('Send message failed: ${e.runtimeType}'));
    }
  }

  @override
  Future<Result<SupportChatMessageAttachment, ExchangeSupportChatFailure>>
  getMessageAttachment(String attachmentId) async {
    try {
      final attachmentModel = await _datasource.getMessageAttachment(
        attachmentId: attachmentId,
      );

      return Ok(attachmentModel.toEntity());
    } on ApiKeyException catch (e, st) {
      log.warning(
        'Support chat: not authenticated',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(NotAuthenticatedFailure());
    } catch (e, st) {
      if (exchangeAuthenticationException(e)?.isUnauthenticated ?? false) {
        return const Err(NotAuthenticatedFailure());
      }
      log.warning(
        'Failed to load support chat attachment',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        LoadAttachmentFailure('Load attachment failed: ${e.runtimeType}'),
      );
    }
  }
}
