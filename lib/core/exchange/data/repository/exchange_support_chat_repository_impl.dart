import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_support_chat_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/support_chat_message_attachment_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';

class ExchangeSupportChatRepositoryImpl
    implements ExchangeSupportChatRepository {
  final ExchangeSupportChatDatasource _datasource;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;
  final bool _isTestnet;

  ExchangeSupportChatRepositoryImpl({
    required ExchangeSupportChatDatasource datasource,
    required BullbitcoinApiKeyDatasource apiKeyDatasource,
    required BullbitcoinApiDatasource bullbitcoinApiDatasource,
    required bool isTestnet,
  }) : _datasource = datasource,
       _apiKeyDatasource = apiKeyDatasource,
       _bullbitcoinApiDatasource = bullbitcoinApiDatasource,
       _isTestnet = isTestnet;

  @override
  Future<List<SupportChatMessage>> getMessages({
    int? page,
    int? pageSize,
  }) async {
    try {
      final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
      if (apiKey == null) {
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      final userSummaryModel = await _bullbitcoinApiDatasource.getUserSummary(
        apiKey.key,
      );
      if (userSummaryModel == null) {
        throw Exception('User summary not found');
      }

      final userId = userSummaryModel.userId;
      if (userId == null) {
        throw Exception('User ID not found in user summary');
      }

      final messageModels = await _datasource.listMessages(
        apiKey: apiKey.key,
        userId: userId,
        page: page,
        pageSize: pageSize,
      );

      return messageModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      if (e is ApiKeyException) {
        rethrow;
      }
      throw Exception('Failed to get messages: $e');
    }
  }

  @override
  Future<void> sendMessage({
    required String text,
    List<SupportChatMessageAttachment>? attachments,
  }) async {
    try {
      final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
      if (apiKey == null) {
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
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
        apiKey: apiKey.key,
        text: text,
        attachments: attachmentModels,
      );
    } catch (e) {
      if (e is ApiKeyException) {
        rethrow;
      }
      throw Exception('Failed to send message: $e');
    }
  }

  @override
  Future<SupportChatMessageAttachment> getMessageAttachment(
    String attachmentId,
  ) async {
    try {
      final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
      if (apiKey == null) {
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      final attachmentModel = await _datasource.getMessageAttachment(
        apiKey: apiKey.key,
        attachmentId: attachmentId,
      );

      return attachmentModel.toEntity();
    } catch (e) {
      if (e is ApiKeyException) {
        rethrow;
      }
      throw Exception('Failed to get message attachment: $e');
    }
  }
}
