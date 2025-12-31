import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/data/models/support_chat_message_attachment_model.dart';
import 'package:bb_mobile/core/exchange/data/models/support_chat_message_model.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:dio/dio.dart';

class ExchangeSupportChatDatasource {
  final Dio _http;
  final _messagesPath = '/ak/api-commcenter';

  ExchangeSupportChatDatasource({required Dio bullbitcoinApiHttpClient})
    : _http = bullbitcoinApiHttpClient;

  Future<List<SupportChatMessageModel>> listMessages({
    required String apiKey,
    required String userId,
    int? page,
    int? pageSize,
  }) async {
    try {
      final params = <String, dynamic>{
        'sortBy': {'id': 'createdAt', 'sort': 'desc'},
        'paginator': {'page': page ?? 1, 'pageSize': pageSize ?? 10},
      };

      final resp = await _http.post(
        _messagesPath,
        data: {
          'jsonrpc': '2.0',
          'id': '0',
          'method': 'listMessages',
          'params': params,
        },
        options: Options(headers: {'X-API-Key': apiKey}),
      );

      if (resp.statusCode != 200) {
        throw Exception('Failed to list messages');
      }

      final error = resp.data['error'];
      if (error != null) {
        throw Exception('Failed to list messages: $error');
      }

      final elements = resp.data['result']['elements'] as List<dynamic>?;
      if (elements == null) return [];

      return elements
          .map(
            (e) => SupportChatMessageModel.fromJsonWithUserId(
              e as Map<String, dynamic>,
              userId,
            ),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendMessage({
    required String apiKey,
    required String text,
    List<SupportChatMessageAttachmentModel>? attachments,
  }) async {
    try {
      log.fine('Datasource: Sending message with text: "$text"');
      final params = <String, dynamic>{'text': text, 'source': 'BULL Mobile'};

      final attachmentsList = attachments
          ?.where((attachment) => attachment.fileData != null)
          .map((attachment) {
            log.fine('Datasource: Processing attachment - ${attachment.fileName} (${attachment.fileSize} bytes, ${attachment.fileType})');
            final encoded = base64Encode(attachment.fileData!);
            log.fine('Datasource: Base64 encoded length: ${encoded.length}');
            return {
              'fileName': attachment.fileName,
              'fileType': attachment.fileType,
              'fileSize': attachment.fileSize,
              'fileData': encoded,
            };
          })
          .toList();

      params['attachments'] = attachmentsList;
      
      log.fine('Datasource: Sending ${attachmentsList?.length ?? 0} attachments to API');

      final requestData = {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'sendMessageToSupport',
        'params': {'element': params},
      };

      final resp = await _http.post(
        _messagesPath,
        data: requestData,
        options: Options(headers: {'X-API-Key': apiKey}),
      );

      log.fine('Datasource: API response status: ${resp.statusCode}');

      if (resp.statusCode != 200) {
        throw Exception('Failed to send message');
      }

      final error = resp.data['error'];
      if (error != null) {
        log.severe('Datasource: API error: $error');
        throw Exception('Failed to send message: $error');
      }
      
      log.fine('Datasource: Message sent successfully');
    } catch (e) {
      log.severe('Datasource: Exception sending message: $e');
      rethrow;
    }
  }

  Future<SupportChatMessageAttachmentModel> getMessageAttachment({
    required String apiKey,
    required String attachmentId,
  }) async {
    try {
      final requestData = {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'getMessageAttachment',
        'params': {'attachmentId': attachmentId},
      };

      final resp = await _http.post(
        _messagesPath,
        data: requestData,
        options: Options(headers: {'X-API-Key': apiKey}),
      );

      if (resp.statusCode != 200) {
        throw Exception('Failed to get message attachment');
      }

      final error = resp.data['error'];
      if (error != null) {
        throw Exception('Failed to get message attachment: $error');
      }

      final result = resp.data['result'] as Map<String, dynamic>?;
      if (result == null) {
        throw Exception('No result in response');
      }

      final fileData = result['fileData'];
      Uint8List? fileDataBytes;

      if (fileData != null) {
        if (fileData is Map<String, dynamic> && fileData['data'] != null) {
          fileDataBytes = Uint8List.fromList(
            List<int>.from(fileData['data'] as List),
          );
        } else if (fileData is List) {
          fileDataBytes = Uint8List.fromList(List<int>.from(fileData));
        } else if (fileData is String) {
          fileDataBytes = Uint8List.fromList(base64Decode(fileData));
        }
      }

      return SupportChatMessageAttachmentModel(
        attachmentId: result['attachmentId'] as String?,
        fileName: result['fileName'] as String?,
        fileType: result['fileType'] as String?,
        fileSize: result['fileSize'] as int?,
        fileData: fileDataBytes,
        messageId: result['messageId'] as String?,
        createdAt: result['createdAt'] != null
            ? DateTime.tryParse(result['createdAt'] as String)
            : null,
      );
    } catch (e) {
      rethrow;
    }
  }
}
