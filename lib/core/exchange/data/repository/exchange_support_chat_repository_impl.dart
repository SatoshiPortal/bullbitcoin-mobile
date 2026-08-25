import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_support_chat_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/support_chat_message_attachment_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';

class ExchangeSupportChatRepositoryImpl
    implements ExchangeSupportChatRepository {
  final ExchangeSupportChatDatasource _datasource;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;
  final bool _isTestnet;

  ExchangeSupportChatRepositoryImpl({
    required this._datasource,
    required this._apiKeyDatasource,
    required this._bullbitcoinApiDatasource,
    required this._isTestnet,
  });

  /// Being logged out is a normal, expected state rather than an exceptional one, so the missing key is returned as a failure instead of being thrown and caught a few lines below.
  Future<Result<String, ExchangeSupportChatFailure>> _apiKey() async {
    final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
    if (apiKey == null) {
      log.warning('Support chat: no API key stored, user is logged out');
      return const Err(NotAuthenticatedFailure());
    }
    return Ok(apiKey.key);
  }

  @override
  Future<Result<List<SupportChatMessage>, ExchangeSupportChatFailure>>
  getMessages({int? page, int? pageSize}) async {
    try {
      final String apiKey;
      switch (await _apiKey()) {
        case Ok(:final value):
          apiKey = value;
        case Err(:final failure):
          return Err(failure);
      }

      final userSummaryModel = await _bullbitcoinApiDatasource.getUserSummary(
        apiKey,
      );
      if (userSummaryModel == null) {
        throw Exception('User summary not found');
      }

      final userId = userSummaryModel.userId;
      if (userId == null) {
        throw Exception('User ID not found in user summary');
      }

      final messageModels = await _datasource.listMessages(
        apiKey: apiKey,
        userId: userId,
        page: page,
        pageSize: pageSize,
      );

      return Ok(messageModels.map((model) => model.toEntity()).toList());
    } on ApiKeyException catch (e, st) {
      log.warning('Support chat: not authenticated', error: e, trace: st);
      return Err(NotAuthenticatedFailure('$e'));
    } catch (e, st) {
      log.warning('Failed to load support chat messages', error: e, trace: st);
      return Err(LoadMessagesFailure('$e'));
    }
  }

  @override
  Future<Result<void, ExchangeSupportChatFailure>> sendMessage({
    required String text,
    List<SupportChatMessageAttachment>? attachments,
  }) async {
    try {
      final String apiKey;
      switch (await _apiKey()) {
        case Ok(:final value):
          apiKey = value;
        case Err(:final failure):
          return Err(failure);
      }

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

      await _datasource.sendMessage(
        apiKey: apiKey,
        text: text,
        attachments: attachmentModels,
      );
      return const Ok(null);
    } on ApiKeyException catch (e, st) {
      log.warning('Support chat: not authenticated', error: e, trace: st);
      return Err(NotAuthenticatedFailure('$e'));
    } catch (e, st) {
      log.warning('Failed to send support chat message', error: e, trace: st);
      return Err(SendMessageFailure('$e'));
    }
  }

  @override
  Future<Result<SupportChatMessageAttachment, ExchangeSupportChatFailure>>
  getMessageAttachment(String attachmentId) async {
    try {
      final String apiKey;
      switch (await _apiKey()) {
        case Ok(:final value):
          apiKey = value;
        case Err(:final failure):
          return Err(failure);
      }

      final attachmentModel = await _datasource.getMessageAttachment(
        apiKey: apiKey,
        attachmentId: attachmentId,
      );

      return Ok(attachmentModel.toEntity());
    } on ApiKeyException catch (e, st) {
      log.warning('Support chat: not authenticated', error: e, trace: st);
      return Err(NotAuthenticatedFailure('$e'));
    } catch (e, st) {
      log.warning(
        'Failed to load support chat attachment',
        error: e,
        trace: st,
      );
      return Err(LoadAttachmentFailure('$e'));
    }
  }
}
